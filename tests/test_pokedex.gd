extends SceneTree

func _init():
    print("--- Running VectorDex Headless Verification Test Suite ---")

    var main_scene = load("res://scenes/main.tscn")
    if not main_scene:
        printerr("FAIL: Could not load res://scenes/main.tscn")
        quit(1)
        return

    var main = main_scene.instantiate()
    root.add_child(main)

    # wait one frame for _ready() and children to initialize
    await process_frame

    print("1. Verifying Core Nodes...")
    assert(main.get_node("%HeroCardPanel") !=null, "HeroCardPanel missing")
    assert(main.get_node("%HeroArtwork") !=null, "HeroArtwork missing")
    assert(main.get_node("%HeroSpotlight") !=null, "HeroSpotlight missing")
    assert(main.get_node("%WatermarkPokeball") !=null or main.find_child("WatermarkPokeball", true, false) != null, "WatermarkPokeball missing")
    assert(main.get_node("%SparkleParticles") != null, "SparkleParticles missing")
    assert(main.get_node("%ShinyBtn") != null, "ShinyBtn missing")
    assert(main.get_node("%PlayCryBtn") != null, "PlayCryBtn missing")
    assert(main.get_node("%WeaknessesContainer") != null, "WeaknessesContainer missing")
    assert(main.get_node("%ResistancesContainer") != null, "ResistancesContainer missing")
    assert(main.get_node("%RandomBtn") != null, "RandomBtn missing")
    assert(main.get_node("%SearchInput") != null, "SearchInput missing")
    print("  -> All core nodes found and linked successfully!")

    print("2. Verifying Pokedex Data...")
    print("  -> Total Pokemon loaded: ", main.all_pokemon.size())
    assert(main.all_pokemon.size() == 151, "Expected 151 Pokemon loaded, got: %d" % main.all_pokemon.size())

    print("3. Testing Bulbasaur (#1) Selection...")
    main.select_pokemon(main.all_pokemon[0])
    assert(main.hero_name.text == "Bulbasaur", "Expected Bulbasaur, got: %s" % main.hero_name.text)
    assert(main.hero_number.text == "#001", "Expected #001, got: %s" % main.hero_name.text)
    assert(main.weaknesses_container.get_child_count() > 0, "Bulbasaur should have weaknesses")
    assert(main.resistances_container.get_child_count() > 0, "Bulbasaur should have resistances")
    print("  -> Bulbasaur Weaknesses: ", main.weaknesses_container.get_child_count(), " chips")
    print("  -> Bulbasaur Resistances: ", main.resistances_container.get_child_count(), " chips")

    print("4. Testing Shiny Mode Toggle...")
    assert(main.is_shiny == false, "Default should not be shiny")
    main._toggle_shiny()
    assert(main.is_shiny == true, "Shiny should now be enabled")
    assert(main.shiny_btn.text == "SHINY ON", "ShinyBtn should display SHINY ON")
    print("  -> Shiny toggled on successfully!")
    main._toggle_shiny()
    assert(main.is_shiny == false, "Shiny toggled back off successfully")

    print("5. Testing Charmander (#4) Selection...")
    main.select_pokemon(main.all_pokemon[3])
    assert(main.hero_name.text == "Charmander", "Expected Charmander, got: %s" % main.hero_name.text)
    assert(main.hero_number.text == "#004", "Expected #004, got: %s" % main.hero_number.text)
    print("  -> Charmander Weaknesses: ", main.weaknesses_container.get_child_count(), " chips")
    print("  -> Charmander Resistances: ", main.resistances_container.get_child_count(), " chips")

    print("6. Testing Search Filter...")
    main._on_search_changed("pika")
    assert(main.filtered_pokemon.size() == 1, "Expected 1 match for 'pika', got: %d" % main.filtered_pokemon.size())
    assert(main.filtered_pokemon[0]["name"].to_lower() == "pikachu", "Expected Pikachu match")
    print("  -> Search correctly filtered to Pikachu!")
    main._on_search_changed("")
    assert(main.filtered_pokemon.size() == 151, "Empty search should restore all 151")

    print("7. Testing Keyboard Navigation & Relative Jumps...")
    main.active_index = 0
    main._navigate_relative(1)
    assert(main.active_pokemon["name"].to_lower() == "ivysaur", "next pokemon after bulbasaur should be ivysaur")
    main._navigate_relative(-1)
    assert(main.active_pokemon["name"].to_lower() == "bulbasaur", "Previous should be bulbasaur")
    print("  -> Relative navigation confirmed!")

    print("8. Testing Random Picker...")
    main._select_random()
    assert(not main.active_pokemon.is_empty(), "Random should pick a valid pokemon")
    print("  -> Randomly selected: ", main.active_pokemon["name"])

    print("--- ALL 8 TESTS PASSED WITH FLYING COLORS! ---")
    quit(0)