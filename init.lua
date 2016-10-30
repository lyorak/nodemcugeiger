led = 4
waitpin = 0
gpio.mode(led,gpio.OUTPUT)
gpio.write(led,gpio.LOW)
gpio.mode(waitpin,gpio.INPUT,gpio.PULLUP)

MYSSID = "Geiger0001"
dofile("credentials.lua")


function synchTime()
   net.dns.resolve("ntp.atomki.mta.hu", 
       function(sk, ip)
           if (ip == nil) then 
               print("NTP DNS fail!") 
               rtctime.set(0)
           else 
               sntp.sync(ip,
                   function(sec,usec,server)
                       tm = rtctime.epoch2cal(sec)                            
                       print(string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
                   end,
                   function()
                       print('Getting NTP time failed!')
                   end
                   )  
           end
       end
       )
end


function startup()
    tmr.unregister(0)
    tmr.unregister(1)
    tmr.unregister(2)
    synchTime()
    if(gpio.read(waitpin) == 1) then
        
        if file.exists("application.lua") then
            print("Running")
            -- the actual application is stored in 'application.lua'
            gpio.write(led,gpio.HIGH)
            dofile("application.lua")
        else 
            print("application.lua deleted or renamed")
        end
    else
        print("waiting for programmer...")
    end
end



ledstate = 1
blinkcnt = 0
function ledblink()
    if ledstate == 0 then
        gpio.write(led,gpio.LOW)
        ledstate = 1
    else
        gpio.write(led,gpio.HIGH)
        ledstate = 0
     end
     if(blinkcnt == 120) then
        node.dsleep(10*60*1000000)  -- sleep for 10 mins
     end
end

if adc.force_init_mode(adc.INIT_VDD33)
then
  node.restart()
  return -- don't bother continuing, the restart is scheduled
end

function saveCredentials(ssid,password)
    file.open("credentials.lua", "w")
    ssidstr = 'SSID = \"' .. ssid .. '\"'
    passstr = 'PASSWORD = \"' .. password .. '\"'
    file.writeline(ssidstr)
    file.writeline(passstr)
    file.close()
end

function getConfig()
    print("Unable to connect to preconfigured SSID")
    print("Starting AP mode with SSID: " .. MYSSID);
    --print("You have two minutes to configure the AP")
    wifi.setmode(wifi.STATIONAP)
    wifi.ap.config({ssid=MYSSID, auth=wifi.OPEN})
    
    enduser_setup.manual(true)

    tmr.alarm(2, 1000, tmr.ALARM_AUTO, ledblink)
    
    enduser_setup.start(
      function()
        enduser_setup.stop()
        ssid, password, bssid_set, bssid=wifi.sta.getconfig()
        saveCredentials(ssid,password)
        print("Connected to wifi as:" .. wifi.sta.getip())        
        tmr.alarm(0, 10, tmr.ALARM_SINGLE, startup)
      end,
      function(err, str)
        print("enduser_setup: Err #" .. err .. ": " .. str)
      end
    );
end


print("Connecting to WiFi access point...")
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID, PASSWORD)
attempts = 6
-- wifi.sta.connect() not necessary because config() uses auto-connect=true by default
tmr.alarm(1, 1000, 1, function()
    if wifi.sta.getip() == nil then
        print("Waiting for IP address...")
        attempts = attempts -1
        if attempts == 0 then
            tmr.stop(1)
  --          tmr.alarm(0, 120000, tmr.ALARM_SINGLE, function()  -- we have two minutes to configure
  --              rtctime.dsleep(10*60*1000000)
  --          end)
            _, reset_reason = node.bootreason()
            if reset_reason == 0 then 
                --print("Power UP!")
                getConfig()
            else
                -- wait for 30 minutes 
                node.dsleep(30*60*1000000) 
            end
        end
    else
        print("WiFi connection established, IP address: " .. wifi.sta.getip())
        startup()
    end
end)
