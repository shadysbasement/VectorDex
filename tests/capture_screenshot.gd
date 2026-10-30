extends SceneTree

func _init():
    var main_scene = load("res://scenes/main.tscn")
    var main = main_scene.instantiate()
    root.add_child(main)

    # wait for a couple frames to ensure shaders, textures and layout compute
    await process_frame
    main.select_pokemon(main.all_pokemon[0])
    for i in range(10):
        await process_frame

    var img = root.get_texture().get_image()
    if img:
        img.save_png("res://pokedex_render.png")
        print("Screenshot successfully saved to res://pokedex_render.png!")
    else:
        printerr("Could not get image from root viewport.")
    quit(0)
