"""Rig the Scenario mesh and export a compact in-place Walk clip for Godot.

Run with Blender: blender --background --python tools/rig_stone_golem.py
The rigid stone plates use deliberately limited blending around their joints.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets/enemies/stone_golem'
SOURCE = ROOT / 'tools/golem_source'
QA = ROOT / '.testdata/golem'
QA.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'source.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
# Bake the imported hierarchy before measuring the world-space anatomy.
for obj in meshes:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
verts = [v.co for o in meshes for v in o.data.vertices]
lo = Vector(tuple(min(v[i] for v in verts) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in verts) for i in range(3)))
factor = 1.35 / (hi.z - lo.z)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for obj in meshes:
    for v in obj.data.vertices:
        v.co = (v.co - center) * factor
        # Tripo faces Blender -Y; turn it toward +Y (Godot's -Z).
        v.co.x = -v.co.x
        v.co.y = -v.co.y
    obj.name = 'GolemStone'
    for poly in obj.data.polygons:
        poly.use_smooth = True
    for mat in obj.data.materials:
        if mat and mat.use_nodes:
            bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf:
                bsdf.inputs['Roughness'].default_value = 0.93
                bsdf.inputs['Metallic'].default_value = 0.0
    obj.data.update()

arm_data = bpy.data.armatures.new('GolemSkeleton')
rig = bpy.data.objects.new('GolemRig', arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
height = 1.35
width = (hi.x - lo.x) * factor

def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = Vector(head) * height
    b.tail = Vector(tail) * height
    if parent:
        b.parent = arm_data.edit_bones[parent]
    return b

bone('Root', (0, 0, 0), (0, 0, .12))
bone('Hips', (0, 0, .39), (0, 0, .52), 'Root')
bone('Chest', (0, 0, .52), (0, 0, .76), 'Hips')
bone('Head', (0, 0, .76), (0, 0, .98), 'Chest')
for side, sign in [('L', 1), ('R', -1)]:
    # Proportions follow the squat, wide-shouldered generated concept.
    shoulder_x = sign * width / height * .31
    elbow_x = sign * width / height * .38
    hand_x = sign * width / height * .40
    bone('UpperArm.' + side, (shoulder_x, 0, .75), (elbow_x, 0, .55), 'Chest')
    bone('Forearm.' + side, (elbow_x, 0, .55), (hand_x, 0, .35), 'UpperArm.' + side)
    bone('Hand.' + side, (hand_x, 0, .35), (hand_x, 0, .24), 'Forearm.' + side)
    bone('Thigh.' + side, (sign * .13, 0, .40), (sign * .13, 0, .24), 'Hips')
    bone('Shin.' + side, (sign * .13, 0, .24), (sign * .13, 0, .085), 'Thigh.' + side)
    bone('Foot.' + side, (sign * .13, 0, .085), (sign * .13, .13, .05), 'Shin.' + side)
bpy.ops.object.mode_set(mode='OBJECT')

def blend(groups, vertex, first, second, value, split, band):
    t = max(0.0, min(1.0, (value - split + band) / (2 * band)))
    if t < 1:
        groups[first].add([vertex], 1 - t, 'REPLACE')
    if t > 0:
        groups[second].add([vertex], t, 'REPLACE')

for obj in meshes:
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for v in obj.data.vertices:
        x, y, z = v.co / height
        side = 'L' if x > 0 else 'R'
        # Prevent an automatic heat solver from linking the hands to the hips.
        arm_boundary = width / height * (.26 if z > .58 else .285)
        if abs(x) > arm_boundary and z > .22:
            if z > .49:
                blend(groups, v.index, 'Forearm.' + side, 'UpperArm.' + side, z, .55, .025)
            else:
                blend(groups, v.index, 'Hand.' + side, 'Forearm.' + side, z, .35, .02)
        elif z < .40:
            if z < .15:
                blend(groups, v.index, 'Foot.' + side, 'Shin.' + side, z, .105, .018)
            elif z < .30:
                blend(groups, v.index, 'Shin.' + side, 'Thigh.' + side, z, .245, .022)
            else:
                blend(groups, v.index, 'Thigh.' + side, 'Hips', z, .38, .025)
        elif z > .76:
            groups['Head'].add([v.index], 1, 'REPLACE')
        else:
            blend(groups, v.index, 'Hips', 'Chest', z, .53, .035)
    mod = obj.modifiers.new('StoneJointDeformation', 'ARMATURE')
    mod.object = rig
    obj.parent = rig

scene = bpy.context.scene
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 49
# A 1.6-second two-step cycle. No horizontal root translation: AI owns movement.
for frame in range(1, 50):
    phase = (frame - 1) / 48 * math.tau
    for pb in rig.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    # The root bone's local Y points upward, so bob without root motion.
    rig.pose.bones['Root'].location.y = .014 * (1 - math.cos(phase * 2))
    rig.pose.bones['Chest'].rotation_euler.y = math.radians(3) * math.sin(phase)
    rig.pose.bones['Head'].rotation_euler.y = -math.radians(2) * math.sin(phase)
    for side, offset in [('L', 0), ('R', math.pi)]:
        p = phase + offset
        rig.pose.bones['Thigh.' + side].rotation_euler.x = math.radians(20) * math.sin(p)
        rig.pose.bones['Shin.' + side].rotation_euler.x = -math.radians(25) * max(0, math.sin(p))
        rig.pose.bones['Foot.' + side].rotation_euler.x = math.radians(7) * math.sin(p)
        rig.pose.bones['UpperArm.' + side].rotation_euler.x = -math.radians(13) * math.sin(p)
        rig.pose.bones['Forearm.' + side].rotation_euler.x = math.radians(4) * (1 + math.sin(p))
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path='rotation_euler', frame=frame)
        if pb.name == 'Root':
            pb.keyframe_insert(data_path='location', frame=frame)
rig.animation_data.action.name = 'Walk'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in meshes:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ASSET / 'stone_golem.glb'),
    export_format='GLB', use_selection=True, export_animations=True,
    export_frame_range=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_skins=True, export_morph=False,
    export_anim_slide_to_zero=True, export_current_frame=False)
print('GOLEM_EXPORT:', len(meshes), 'meshes;', sum(len(o.data.polygons) for o in meshes), 'faces;', len(rig.data.bones), 'bones')

# Front and back QA contact sheets, plus a quarter-cycle animated pose.
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.world.color = (.5, .5, .5)
scene.view_settings.view_transform = 'Standard'
scene.render.image_settings.file_format = 'PNG'

def aim(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()

bpy.ops.object.light_add(type='AREA', location=(2, 3, 4))
bpy.context.object.data.energy = 350
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 4
aim(bpy.context.object, (0, 0, .7))
bpy.ops.object.light_add(type='AREA', location=(-2, -2, 2))
bpy.context.object.data.energy = 200
bpy.context.object.data.size = 3
aim(bpy.context.object, (0, 0, .7))
bpy.ops.object.camera_add(location=(1.7, 3, 1.7))
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 1.85
scene.camera = camera
for name, location, frame in [('front', (0, 3, 1.05), 1), ('back', (0, -3, 1.05), 1), ('walk', (1.7, 3, 1.5), 13)]:
    camera.location = location
    aim(camera, (0, 0, .68))
    scene.frame_set(frame)
    scene.render.filepath = str(QA / (name + '.png'))
    bpy.ops.render.render(write_still=True)
