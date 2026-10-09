"""Snag A Goober - Blender modeling library.

Every model is built from code so the roster is reproducible and editable.
Conventions (see Assets/AssetDocumentation/pipeline.md):
  * 1 Blender unit = 1 Roblox stud.
  * Front of a character faces -Y, up is +Z, feet rest on Z = 0, origin at the
    bottom centre.
  * One mesh object per material slot, named  <AssetId>__<Slot>.  Roblox colours
    and materials are applied in Studio from the slot name (see Shared/Palette).
  * All objects of an asset are parented to an Empty named <AssetId>.
"""
import math
import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# Preview colours only (Studio re-colours by slot name).
SLOT_PREVIEW = {
    "Eye": (1, 1, 1),
    "Pupil": (0.02, 0.02, 0.03),
    "Mouth": (0.25, 0.03, 0.06),
    "Tongue": (1.0, 0.35, 0.45),
    "Tooth": (1, 1, 0.95),
}


def _mat(name, color):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = 0.45
    m.diffuse_color = (*color, 1)
    return m


def superellipsoid(e_xy=1.0, e_z=1.0):
    """Deform a unit sphere point into a superellipsoid (e<1 = boxier)."""

    def f(co):
        def s(v, e):
            return math.copysign(abs(v) ** e, v)

        return Vector((s(co.x, e_xy), s(co.y, e_xy), s(co.z, e_z)))

    return f


def taper(top=1.0, bottom=1.0, axis_min=-1.0, axis_max=1.0):
    """Scale X/Y linearly along Z between bottom and top factors."""

    def f(co):
        t = (co.z - axis_min) / max(1e-6, axis_max - axis_min)
        k = bottom + (top - bottom) * max(0.0, min(1.0, t))
        return Vector((co.x * k, co.y * k, co.z))

    return f


def chain(*fns):
    def f(co):
        for fn in fns:
            co = fn(co)
        return co

    return f


# Slots built in Roblox from native parts (Part + sphere/block) instead of
# uploaded meshes. Roblox's automated mesh moderation rejected several "Eye"
# meshes (pairs of white spheres) as false positives, so eyes and pupils are
# never uploaded as meshes: their shapes are exported as specs instead
# (Assets/AssetDocumentation/native_parts.json) and rebuilt by
# tools/process_import.luau. Set to False only for local preview renders.
NATIVE_SLOTS = {"Eye", "Pupil"}
NATIVE_EXPORT = True
NATIVE = {}  # asset id -> [ {slot, shape, center, size} ] (asset-local Blender coords)


class Asset:
    """Accumulates primitives per material slot, then builds objects."""

    def __init__(self, asset_id, colors=None, collection=None):
        self.id = asset_id
        self.colors = dict(SLOT_PREVIEW)
        self.colors.update(colors or {})
        self.slots = {}  # slot -> bmesh
        self.native = []
        self.collection = collection or bpy.context.scene.collection

    # ---------------------------------------------------------------- core
    def _bm(self, slot):
        if slot not in self.slots:
            self.slots[slot] = bmesh.new()
        return self.slots[slot]

    def _commit(self, slot, bm, loc, rot, scale, deform, smooth):
        for v in bm.verts:
            co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
            if deform:
                co = deform(co)
            v.co = co
        rm = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(loc)) @ rm, verts=bm.verts)
        for face in bm.faces:
            face.smooth = smooth
        if slot in NATIVE_SLOTS:
            # record the primitive's bounding box; also keep it as preview
            # geometry unless we're building the upload export
            xs = [v.co.x for v in bm.verts]
            ys = [v.co.y for v in bm.verts]
            zs = [v.co.z for v in bm.verts]
            self.native.append({
                "slot": slot,
                "shape": "box" if len(bm.verts) == 8 else "ball",
                "center": [round((min(xs) + max(xs)) / 2, 4), round((min(ys) + max(ys)) / 2, 4), round((min(zs) + max(zs)) / 2, 4)],
                "size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
            })
            if NATIVE_EXPORT:
                bm.free()
                return
        tmp = bpy.data.meshes.new("_tmp")
        bm.to_mesh(tmp)
        bm.free()
        self._bm(slot).from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    # ---------------------------------------------------------- primitives
    def sphere(self, slot, r=1.0, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0),
               seg=24, rings=14, deform=None, smooth=True):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        s = (scale[0] * r, scale[1] * r, scale[2] * r)
        if deform:
            # deform operates on unit-sphere coords before scaling
            for v in bm.verts:
                v.co = deform(v.co.copy())
        self._commit(slot, bm, loc, rot, s, None, smooth)

    def ico(self, slot, r=1.0, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), sub=1, smooth=False):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        self._commit(slot, bm, loc, rot, (scale[0] * r, scale[1] * r, scale[2] * r), None, smooth)

    def cyl(self, slot, r=0.5, depth=1.0, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
            r2=None, seg=20, smooth=True, cap=True, flip=False):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg,
                              radius1=r, radius2=r if r2 is None else r2, depth=depth)
        if flip:  # inward-facing walls (inside of tubs/funnels)
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        self._commit(slot, bm, loc, rot, scale, None, smooth)
        # flat caps look better: caller can pass smooth=False for hard objects

    def cone(self, slot, r=0.5, depth=1.0, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
             seg=20, smooth=True, tip=0.0):
        self.cyl(slot, r=r, r2=tip, depth=depth, loc=loc, rot=rot, scale=scale, seg=seg, smooth=smooth)

    def box(self, slot, size=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), round_e=None, smooth=False):
        if round_e:
            # rounded box from a superellipsoid sphere
            self.sphere(slot, r=1.0, loc=loc, rot=rot, scale=(size[0] / 2, size[1] / 2, size[2] / 2),
                        seg=24, rings=16, deform=superellipsoid(round_e, round_e), smooth=True)
            return
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        self._commit(slot, bm, loc, rot, size, None, smooth)

    def torus(self, slot, R=1.0, r=0.2, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
              seg=24, sides=10, smooth=True, arc=360.0):
        bm = bmesh.new()
        closed = arc >= 359.9
        nseg = seg if closed else seg + 1
        rings = []
        for i in range(nseg):
            a = math.radians(arc) * i / seg
            ring = []
            for j in range(sides):
                b = 2 * math.pi * j / sides
                x = (R + r * math.cos(b)) * math.cos(a)
                y = (R + r * math.cos(b)) * math.sin(a)
                z = r * math.sin(b)
                ring.append(bm.verts.new((x, y, z)))
            rings.append(ring)
        count = seg if closed else seg
        for i in range(count):
            r0 = rings[i]
            r1 = rings[(i + 1) % nseg]
            for j in range(sides):
                bm.faces.new((r0[j], r1[j], r1[(j + 1) % sides], r0[(j + 1) % sides]))
        if not closed:
            bm.faces.new(list(reversed(rings[0])))
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._commit(slot, bm, loc, rot, scale, None, smooth)

    def tube(self, slot, points, r=0.1, sides=8, smooth=True, r_end=None):
        """Sweep a circle along a polyline (for tentacles, canes, tails)."""
        bm = bmesh.new()
        pts = [Vector(p) for p in points]
        rings = []
        n = len(pts)
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            a = d.cross(up).normalized()
            b = d.cross(a).normalized()
            rr = r if r_end is None else r + (r_end - r) * (i / (n - 1))
            ring = [bm.verts.new(p + (a * math.cos(2 * math.pi * j / sides) + b * math.sin(2 * math.pi * j / sides)) * rr)
                    for j in range(sides)]
            rings.append(ring)
        for i in range(n - 1):
            for j in range(sides):
                bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % sides], rings[i][(j + 1) % sides]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._commit(slot, bm, (0, 0, 0), (0, 0, 0), (1, 1, 1), None, smooth)

    # -------------------------------------------------------------- helpers
    def eye(self, loc, size=0.28, look=(0, 0), pupil=0.55, lid=None, flat=0.55):
        """A googly eye on the front (-Y) of a body. look shifts the pupil."""
        x, y, z = loc
        self.sphere("Eye", r=size, loc=(x, y, z), scale=(1, flat, 1), seg=18, rings=12)
        pr = size * pupil
        self.sphere("Pupil", r=pr, loc=(x + look[0] * size * 0.35, y - size * flat * 0.78,
                                      z + look[1] * size * 0.35), scale=(1, 0.45, 1), seg=14, rings=10)
        self.sphere("Eye", r=pr * 0.32, loc=(x + look[0] * size * 0.35 + pr * 0.35,
                                         y - size * flat * 0.98, z + look[1] * size * 0.35 + pr * 0.35),
                    seg=8, rings=6)
        if lid:  # sleepy eyelid in body colour
            self.sphere(lid, r=size * 1.06, loc=(x, y, z + size * 0.05), scale=(1, flat * 1.08, 0.62),
                        seg=18, rings=10)

    def smile(self, loc, width=0.5, slot="Mouth", thick=0.06, frown=False, tilt=0.0):
        """Curved smile on the front face: half torus standing in the XZ plane."""
        rx = 90 if frown else -90
        self.torus(slot, R=width / 2, r=thick, loc=loc, rot=(rx + tilt, 0, 0), seg=14, sides=8, arc=180)

    def feet(self, slot, spread=0.45, size=0.28, y=-0.05):
        for sx in (-1, 1):
            self.sphere(slot, r=size, loc=(sx * spread, y, size * 0.45), scale=(1.0, 1.35, 0.55), seg=14, rings=8)

    # ---------------------------------------------------------------- build
    def build(self, offset=(0, 0, 0)):
        NATIVE[self.id] = list(self.native)
        self.native = []
        root = bpy.data.objects.new(self.id, None)
        root.empty_display_type = "PLAIN_AXES"
        root.location = offset
        self.collection.objects.link(root)
        objs = []
        for slot, bm in self.slots.items():
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            me = bpy.data.meshes.new(f"{self.id}__{slot}")
            bm.to_mesh(me)
            bm.free()
            me.validate()
            ob = bpy.data.objects.new(f"{self.id}__{slot}", me)
            col = self.colors.get(slot, (0.8, 0.8, 0.8))
            ob.data.materials.append(_mat(f"SAG_{self.id}_{slot}", col))
            self.collection.objects.link(ob)
            ob.parent = root
            objs.append(ob)
        self.slots = {}
        return root, objs


def clear_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    for ob in list(col.objects):
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)
    return col


def tri_count(objs):
    total = 0
    for ob in objs:
        if ob.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    return total


def hex_rgb(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # Blender colours are linear
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)
