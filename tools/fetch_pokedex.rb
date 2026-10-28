#!/usr/bin/env ruby
# frozen_string_literal: true

# ===================================================
# VectorDex Asset & Data Ingestion Pipeline
#
# i aint writin like 500 lines of async JS
# boilerplate when ruby does this in 100 lines
# with native threads
#
# im gonna make it fetch pokemon data from PokeAPI,
# grab the crispy high-res official artwork,
# download the raw in-game cry audio (.ogg), clean
# up weird game boy flavor text formatting, and dump it
# into clean JSON that godot can swallow instantly
# ====================================================

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'optparse'

# Config / Paths
BASE_DIR = File.expand_path('..', __dir__)
DATA_DIR = File.join(BASE_DIR, 'data')
ARTWORK_DIR = File.join(BASE_DIR, 'assets', 'images', 'artwork')
CRIES_DIR = File.join(BASE_DIR, 'assets', 'audio', 'cries')

FileUtils.mkdir_p(DATA_DIR)
FileUtils.mkdir_p(ARTWORK_DIR)
FileUtils.mkdir_p(CRIES_DIR)

options = {
  count: 151, # Gen 1 default. Set to 251 for johto or 1025 for chaos
  threads: 8  # gotta keep it respectful to PokeAPI servers, i dont wanna get IP banned lmao
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby fetch_pokedex.rb [options]'
  opts.on('-c', '--count N', Integer, 'Number of Pokemon to fetch (default: 151)') do |c|
    options[:count] = c
  end
  opts.on('-t', '--threads N', Integer, 'Worker thread concurrency (default: 8)') do |t|
    options[:threads] = t
  end
end.parse!

puts "\e[1;36m[VectorDex Pipeline]\e[0m Spinning up Ruby workers for #{options[:count]} Pokemon..."

# Helper for GET requests with gentle retries cuz wifi hiccups happen
def fetch_json(url, max_retries = 3)
  retries = 0
  begin
    uri = URI(url)
    res = Net::HTTP.get_response(uri)
    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    elsif res.is_a?(Net::HTTPRedirection)
      fetch_json(res['location'], max_retries)
    else
      nil
    end
  rescue StandardError => e
    retries += 1
    if retries <= max_retries
      sleep(0.5 * retries)
      retry
    end
    warn "Failed to fetch #{url}: #{e.message}"
    nil
  end
end

def download_binary(url, dest_path, max_retries = 3)
  return true if File.exist?(dest_path) && File.size(dest_path) > 100
    
  retries = 0
  begin
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https')) do |http|
      req = Net::HTTP::Get.new(uri)
      http.request(req) do |response|
        if response.is_a?(Net::HTTPSuccess)
          File.open(dest_path, 'wb') do |file|
            response.read_body { |chunk| file.write(chunk) }
          end
          return true
        elsif response.is_a?(Net::HTTPRedirection)
          return download_binary(response['location'], dest_path, max_retries)
        end
      end
    end
  rescue StandardError => e
    retries += 1
    if retries <= max_retries
      sleep(0.5 * retries)
      retry
    end
    return false
  end
  false
end

queue = Queue.new
(1..options[:count]).each { |id| queue << id }

mutex = Mutex.new
results = []
completed = 0
total = options[:count]

workers = Array.new(options[:threads]) do
  Thread.new do
    until queue.empty?
      id = nil
      begin
        id = queue.pop(true)
      rescue ThreadError
        break
      end

      #1. Fetch main pokemon data
      poke_data = fetch_json("https://pokeapi.co/api/v2/pokemon/#{id}")
      species_data = fetch_json("https://pokeapi.co/api/v2/pokemon-species/#{id}")

      next unless poke_data
        
      name = poke_data['name'].capitalize
      # Types
      types = poke_data['types'].map { |t| t.dig('type', 'name') }

      # Stats mapping
      stats_map = {}
      total_stat = 0
      poke_data['stats'].each do |s|
        stat_name = s.dig('stat', 'name')
        val = s['base_stat']
        stats_map[stat_name] = val
        total_stat += val
      end

      # Abilities
      abilities = poke_data['abilities'].map do |a|
        {
          name: a.dig('ability', 'name').split('-').map(&:capitalize).join(' '),
          is_hidden: a['is_hidden']
        }
      end

      # Height in meters, weight in kg (API gives decimeters and hectograms)
      height_m = (poke_data['height'].to_f / 10.0).round(1)
      weight_kg = (poke_data['weight'].to_f / 10.0).round(1)

      # Genus and Flavor text from species
      genus = 'Pokemon'
      flavor = 'No description available in the database.'
      if species_data
        en_genus = species_data['genera']&.find { |g| g.dig('language', 'name') == 'en' }
        genus = en_genus['genus'] if en_genus
          
        en_flavor = species_data['flavor_text_entries']&.find { |f| f.dig('language', 'name') == 'en'}
        if en_flavor
          # Game Boy text has random newlines, form feeds (\f), and weird hyphens, clean it up.
          flavor = en_flavor['flavor_text']
                    .gsub("\f", ' ')
                    .gsub("\n", ' ')
                    .gsub(/\s+/, ' ')
                    .strip
        end
      end

      # Artwork download
      artwork_url = poke_data.dig('sprites', 'other', 'official-artwork', 'front_default') ||
                    poke_data.dig('sprites', 'front_default')
      artwork_file = File.join(ARTWORK_DIR, "#{id}.png")
      download_binary(artwork_url, artwork_file) if artwork_url
        
      # Cry audio download (heads up, PokeAPI cries repo serves mp3 headers despite the .ogg url)
      cry_url = poke_data.dig('cries', 'latest') ||
                "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/#{id}.ogg"
      cry_file = File.join(CRIES_DIR, "#{id}.ogg")
      download_binary(cry_url, cry_file) if cry_url
        

      entry = {
        id: id,
        number: format('#%03d', id),
        name: name,
        genus: genus,
        types: types,
        height: height_m,
        weight: weight_kg,
        stats: {
          hp: stats_map['hp'] || 50,
          attack: stats_map['attack'] || 50,
          defense: stats_map['defense'] || 50,
          special_attack: stats_map['special-attack'] || 50,
          special_defense: stats_map['special-defense'] || 50,
          speed: stats_map['speed'] || 50,
          total: total_stat
        },
        abilities: abilities,
        flavor_text: flavor,
        artwork_path: "res://assets/images/artwork/#{id}.png",
        cry_path: "res://assets/audio/cries/#{id}.ogg"
      }

      mutex.synchronize do
        results << entry
        completed += 1
        pct = (completed.to_f / total * 100).round
        print "\r\e[1;32m[Progress]\e[0m #{completed}/#{total} (#{pct}%) - \e[33m#{name}\e[0m    "
      end
    end
  end
end

workers.each(&:join)
puts "\n"

# Sort by id so bulbasaur is #1, not whoever finished downloading first
results.sort_by! { |p| p[:id] }

output_path = File.join(DATA_DIR, 'pokedex.json')
File.write(output_path, JSON.pretty_generate(results))

puts "\e[1;35m[Done!]\e[0m Successfully bundled #{results.size} Pokemon entries into \e[1m#{output_path}\e[0m."
puts "Artwork in: assets/images/artwork/"
puts "Cries in: assets/audio/cries/"
