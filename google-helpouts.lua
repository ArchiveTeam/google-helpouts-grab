dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if item_type == "user" and (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if string.match(url, "/"..item_value) and string.match(url, "helpouts%.google%.com") then
      addedtolist[url] = true
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  local function check(url, origurl)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      elseif string.match(origurl, "/api/offer/") then
        if not (string.match(url, "photo%.jpg") or string.match(url, "/votereview/")) then
          table.insert(urls, { url=url })
          addedtolist[url] = true
        end
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end
  
  if item_type == "user" then
    if string.match(url, "/"..item_value) then
      html = read_file(file)
      for newurl in string.gmatch(html, '"(/[^"]+)"') do
        if string.match(newurl, "/"..item_value) then
          check("https://helpouts.google.com"..newurl, url)
        end
      end
      for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
        if (string.match(newurl, "/"..item_value) and string.match(url, "helpouts%.google%.com")) or (string.match(newurl, "googlevideo%.com") and not string.match(url, "/api/offer/")) or string.match(newurl, "gstatic%.com") or string.match(newurl, "googleusercontent%.com") then
          check(newurl, url)
        end
      end
      if string.match(html, "[0-9]+/[0-9a-zA-Z]+/%?mr=[0-9]+&nr=[0-9]+") then
        check("https://helpouts.google.com/api/offer/"..item_value.."/"..string.match(html, "[0-9]+/([0-9a-zA-Z]+)/%?mr=[0-9]+&nr=[0-9]+").."?format=JSPB&authuser&xsrf=null&nr="..string.match(html, "[0-9]+/[0-9a-zA-Z]+/%?mr=[0-9]+&nr=([0-9]+)").."&mr="..string.match(html, "[0-9]+/[0-9a-zA-Z]+/%?mr=([0-9]+)&nr=[0-9]+").."&rt=j", url)
      end
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 1")

    tries = tries + 1

    if tries >= 15 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.5 * (math.random(75, 100) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
