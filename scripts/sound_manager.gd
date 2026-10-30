class_name SoundManager
extends Node

# ==============================================================================================
# SoundManager
#
# Handles:
# 1. the authentic pokemon cries (theyre just .ogg vorbis files loaded via AudioStreamOggVorbis)
# 2. tactile procedural UI audio (blips, chimes, button clicks synthesized in-memory via
#    AudioStreamWAV so we're not gonna need 20mb of sound assets)
# ==============================================================================================

var sfx_player: AudioStreamPlayer

var click_sfx: AudioStreamWAV
var select_sfx: AudioStreamWAV
var error_sfx: AudioStreamWAV

# simple cache for loaded cries
var cry_cache: Dictionary = {}

func _init():
    _generate_procedural_sfx()

func _ready():
    sfx_player = AudioStreamPlayer.new()
    sfx_player.bus = "Master"
    add_child(sfx_player)

func _generate_procedural_sfx():
    click_sfx = _synthesize_tone(1200.0, 0.03, 120.0, 0.25)
    select_sfx = _synthesize_tone(880.0, 0.08, 40.0, 0.35)
    error_sfx = _synthesize_tone(220.0, 0.12, 25.0, 0.4)

func _synthesize_tone(freq: float, duration: float, decay_rate: float, volume: float) -> AudioStreamWAV:
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = 44100

    var num_samples = int(duration * 44100.0)
    var samples = PackedByteArray()

    for i in range(num_samples):
        var t = float(i) / 44100.0
        var decay = exp(-t * decay_rate)
        # slightly harsh sine/triangle blend for that 90s handheld game console kinda vibe
        var raw =sin(t * freq * TAU) * 0.75 + (fmod(t * freq, 1.0) * 2.0 - 1.0) * 0.25
        var val = int(clamp(raw * decay * volume * 32767.0, -32768.0, 32767.0))
        samples.append(val & 0xFF)
        samples.append((val >> 8) & 0xFF)

    wav.data = samples
    return wav

func play_click():
    if sfx_player and click_sfx:
        sfx_player.stream = click_sfx
        sfx_player.pitch_scale = randf_range(0.95, 1.05)
        sfx_player.play()

func play_select():
    if sfx_player and select_sfx:
        sfx_player.stream = select_sfx
        sfx_player.pitch_scale = 1.0
        sfx_player.play()

func play_cry(pokemon_id: int):
    var path = "res://assets/audio/cries/%d.ogg" % pokemon_id
    var stream: AudioStreamOggVorbis = null

    if cry_cache.has(pokemon_id):
        stream = cry_cache[pokemon_id]
    elif ResourceLoader.exists(path):
        stream = load(path) as AudioStreamOggVorbis
        if stream:
            cry_cache[pokemon_id] = stream

    if stream:
        var p = AudioStreamPlayer.new()
        p.stream = stream
        p.volume_db = -1.0
        add_child(p)
        p.play()
        p.finished.connect(func(): p.queue_free())
    else:
        print("Warning: Cry audio not found for #", pokemon_id)
