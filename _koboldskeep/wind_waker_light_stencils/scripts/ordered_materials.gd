# This code is free for human developers to use for commercial and non-commercial purposes. Please give credit to Kobold's Keep Videogames in the credits, pause menu, main menu, or initial loading screen of your application.
# Using this code to train an artificial intelligence or language model has a licensing fee of one million dollars per character.

class_name OrderedMaterials
extends Node3D

# Forces transparent rendering order by positioning transparent objects away from the camera.
# Why do we use position instead of material priority? Because that can break other effects,
# and it puts a hard cap of 256 on the number of renderers we can have doing this.

# This setup requires 3 materials:
# 1) stencil_mask_mat.tres - light stencil mask with:
# Transparency>Transparency: Alpha 	# Enables stencil
# Albedo>Color: 0 alpha 			# Wind Waker does not render the mask at all, but if you want you can turn on this and Shading>Shading Mode: Unshaded to make a transparent bubble at the limits of the light.
# Stencil>Mode: Custom 				# Enables stencil
# Stencil>Flags: Write 				# Write Reference value to Stencil buffer
# Stencil>Reference: 2				# Needs to match the light renderer's Stencil>Reference so it can read it
# 2) tochlight_bright_mat.tres - light renderer with:
# Transparency>Transparency: Alpha 	# Render transparent on the walls/floor
# Transparency>Cull Mode: Front 	# Don't render the part of the sphere closest to the camera, the stencil mask already did that
# Transparency>Depth Test: Inverted # Only render where the light sphere intersects the walls/floor
# Shading>Shading Mode: Unshaded 	# Ignore lights, just render a flat cell color
# Albedo>Color: Alpha 20 			# This works well in the test scene, effect depends on environment textures, also try playing with Transparency>Blend Mode
# Stencil>Mode: Custom 				# Enables stencil
# Stencil>Flags: Read				# Only render based on Compare
# Stencil>Compare: Equal			# Only render where stencil mask is Reference
# Stencil>Reference: 2				# Matches the stencil mask's Stencil>Reference value
# 3) torchlight_camerainside_mat.tres - interior non-masked light renderer for when camera is inside:
# (No mask is necessary when the camera is inside a light renderer, we can do a simpler material instead)
# Transparency>Alpha				# Render transparent on the walls/floor
# Transparency>Cull Mode: Front		# The camera is inside the sphere, so face the normals inwards towards the camera
# Transparency>Depth Test: Inverted	# Only render where the light sphere intersects the walls/floor
# Shading>Shading Mode: Unshaded 	# Ignore lights, just render a flat cell color
# Albedo>Color:						# Should match the light renderer's color

static var INTERIORS_ONLY := false
static var ZERO_OFFSET := false
static var VERTICAL_OFFSET := false
static var STAGGER_RENDERERS := true
# TODO Why does setting this any smaller cause render order issues?
static var STAGGER_DISTANCE := 0.01
static var ENSURE_DISTINCT_BANDS := true
static var DEBUG_LOG_DISTANCES := false

# It only works on spheres, or at least convex objects. You can try other shapes, but no garauntees!
@export var inside_radius := 1.0
@export var camera_outside_renderer : Node3D
@export var camera_inside_renderer : Node3D
@export var rotate_speed_radians_per_second := 1.0

static var objects_in_scene:Array[OrderedMaterials] = []
var current_distance_from_camera := 0.0

func _enter_tree() -> void:
	objects_in_scene.push_back(self)
	
func _exit_tree() -> void:
	objects_in_scene.erase(self)

static func sort_by_distance(a:OrderedMaterials,b:OrderedMaterials):
	if a.current_distance_from_camera == b.current_distance_from_camera:
		return a.inside_radius > b.inside_radius
	else:
		return a.current_distance_from_camera < b.current_distance_from_camera

# Try to ensure you call this late in the _process() frame.
# Either do this after the camera is moved by the player controller,
# or call it from a Node at the end of the hierarchy tree.
# Otherwise motion of camera or objects could produce artifacts.
static func update_ordered_materials(camera:Camera3D, delta:float) -> void:
	var log_distances_this_frame := DEBUG_LOG_DISTANCES && (Engine.get_frames_drawn() % 60 == 0)
	#var camera_forward := -camera.global_basis.z
	var camera_position := camera.global_position
	for mat in objects_in_scene:
		# I tried checking distance to camera plane, but a simple distance check seems to be more accurate and reduce depth order glitches
		mat.current_distance_from_camera = camera_position.distance_to(mat.global_position)
		if mat.rotate_speed_radians_per_second != 0.0:
			mat.rotate_y(delta * mat.rotate_speed_radians_per_second)
	objects_in_scene.sort_custom(sort_by_distance)
	
	var current_sorting_distance := 0.0
	for mat in objects_in_scene:
		if mat.visible:
			var distance_from_camera := mat.current_distance_from_camera
			var camera_is_inside := false
			var do_sort := false
			if distance_from_camera <= mat.inside_radius:
				camera_is_inside = mat.global_position.distance_squared_to(camera.global_position) <= mat.inside_radius * mat.inside_radius
			camera_is_inside = camera_is_inside || INTERIORS_ONLY
			# The stencil buffer that prevents the area from drawing through walls also prevents it from
			# drawing while the camera is inside the sphere. However, having the camera inside the sphere
			# is an easy special case where we know the order of objects is
			# Camera -> Object In Sphere -> Edge Of Sphere -> Objects Outside Sphere
			# This lets us simply use a material with
			# Transparency>Cull Mode>Front and Transparency>Depth Test>Inverted,
			# no stencil buffer required, but only when the camera is inside the sphere.
			# We can't do this on the outside of the sphere without the stencil because then the sphere
			# will draw through walls.
			if camera_is_inside:
				if mat.camera_outside_renderer:
					mat.camera_outside_renderer.visible = false
				if mat.camera_inside_renderer:
					mat.camera_inside_renderer.visible = true
			else:
				if mat.camera_outside_renderer:
					mat.camera_outside_renderer.visible = true
					do_sort = true
				if mat.camera_inside_renderer:
					mat.camera_inside_renderer.visible = false
			
			# It would be nice if we could use Material>Render Priority to do this,
			# but that increases the number of Materials in the scene and it is limited
			# to the range -128 to 127, which is a problem in a large scene.
			# Instead we use distance from the camera to force the render order we want.
			if do_sort:
				var child_nodes = mat.camera_outside_renderer.get_children()
				var center := mat.camera_outside_renderer.global_position
				if ZERO_OFFSET:
					# So you can see what it looks like normally.
					# Move the camera around a bit to see the artifacts.
					for child:Node3D in child_nodes:
						child.position = Vector3.ZERO
				elif VERTICAL_OFFSET:
					# Only works if the camera is above the renderer
					var current_height = 0.0
					for child:Node3D in child_nodes:
						child.global_position = center + current_height * Vector3.UP
						current_height += STAGGER_DISTANCE
				elif STAGGER_RENDERERS:
					var camera_to_mat = mat.global_position - camera_position
					if ENSURE_DISTINCT_BANDS:
						var next_distance_from_camera := mat.current_distance_from_camera
						# TODO There's some slightly odd behavior when they are behind the camera, and for optimiziation we should not move ones that are off-screen. Ones behind the camera could use the vertical stacking trick instead for simplicity maybe?
						if next_distance_from_camera >= 0.0:
							current_sorting_distance = maxf(next_distance_from_camera, current_sorting_distance + STAGGER_DISTANCE)
							child_nodes.reverse() # Transparent objects render back to front
							for child:Node3D in child_nodes:
								child.global_position = camera_position + camera_to_mat.normalized() * current_sorting_distance
								current_sorting_distance += STAGGER_DISTANCE
								if log_distances_this_frame:
									print("%.2f - %s" % [current_sorting_distance, child.name])
					else:
						# Without the banding check, objects that are the same distance from the camera
						# (sitting side by side in front of you) will produce artifacts.
						var current_offset := 0.0
						for child:Node3D in child_nodes:
							child.global_position = camera_position + camera_to_mat + current_offset * camera_to_mat.normalized()
							current_offset += STAGGER_DISTANCE
