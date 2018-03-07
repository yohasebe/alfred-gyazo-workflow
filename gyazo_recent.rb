$: << File.dirname(__FILE__)
require 'net/http'
require 'open-uri'
require 'uri'
require 'json'
require 'pp'
require 'tempfile'
require 'time'
require 'fileutils'

$default_num_images = 10
$api_url = "https://api.gyazo.com/api/images"
$data_path = ENV['alfred_workflow_data']
$cache_path = ENV['alfred_workflow_cache']
FileUtils::mkdir_p $cache_path unless File.exist?($cache_path)

num = ARGV[0]
if ARGV.empty?
  $num_images = $default_num_images
else
  num = ARGV[0].to_i
  $num_images = ARGV[0].to_i
end

def check_token
  begin
    f = File.open(File.join($data_path, ".gyazo_access_token"), 'r')
    $access_token = f.read.strip
    f.close
    if $access_token == ""
      return false
    else
      return true
    end
  rescue
    return false
  end
end

def download_img(url)
  file_path = File.join($cache_path, File.basename(url))
  unless File.exist?(file_path)
    open(file_path, 'wb') do |output|
      open(url) do |data|
        output.write(data.read)
      end
    end 
  end
  return file_path
end

def error_message
  return {"items" => [
    {
      "title": "Set number within the range of 1-100",
      "subtitle": 'or just type "gri"',
      "arg": "no token"
    }
  ]}.to_json.strip
end

def get_gyazo_data
  num = $num_images
  if num == 0 || num > 100
    return error_message
  elsif num < 20
    num_pages = 1
  elsif num % 20 == 0
    num_pages = num / 20
  else
    num_pages = num / 20 + 1
  end

  remeinder = num % 20
  items = []
  per_page = 20
  per_page = num if num < 20
  
  num_pages.times do |i|
    page = i + 1
    per_page = remeinder if page == num_pages
    img_url = $api_url + "?access_token=#{$access_token}&page=#{page}&per_page=#{per_page}" 
    uri = URI.parse(img_url)
    json = Net::HTTP.get(uri)
    returned_items = JSON.parse(json)
    break if returned_items.empty?
    items += returned_items
  end

  results = {"items" => []} 
  width = items.size.to_s.length
  items.each_with_index do |item, i|
    idx = "[" + (i + 1).to_s.rjust(width, "0") + "]"
    title =File.basename(item["url"])
    thumb_url = item["thumb_url"]
    created_at = item["created_at"]
    created = Time.parse(created_at).strftime("%Y-%m-%d %H:%M:%S")
    permalink_url = item["permalink_url"]
    img_url = item["url"]
    local_img = download_img(thumb_url)
    item_data = {
      "valid": true,
      "title":  idx + " " + created,
      "subtitle": title,
      "icon": {
        "type": "icon",
        "path": local_img,
      },
      "arg": permalink_url,
      "mods": { #cmd/alt/shift/fn/ctrl
          "cmd": {
              "subtitle": "Copy image url to clipboard",
              "arg":img_url 
          },
          "alt": {
              "subtitle": "Copy markdown to clipboard",
              "arg": "[![#{permalink_url}](#{img_url})](#{permalink_url})"
          },
          "shift": {
              "subtitle": "Copy HTML snippet to clipboard",
              "arg": "<a href='#{permalink_url}'/><img src='#{img_url}' alt='#{permalink_url}'></img></a>"
          },
      }
    }
    results["items"] << item_data
  end
  return results.to_json.strip
end

def prompt
  error_obj = {"items" => [
    {
      "title": "Set account token first",
      "subtitle": "set gsu token <access_token>",
      "arg": "no token"
    }
  ]}
  return error_obj.to_json.strip
end

if(check_token)
  print get_gyazo_data
else
  print prompt
end

