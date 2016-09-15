led = 4
gpio.mode(led,gpio.OUTPUT)
gpio.write(led,gpio.LOW)

MYSSID = "Geiger0001"
dofile("credentials.lua")


function synchTime()
    net.dns.resolve("ntp.atomki.mta.hu", 
        function(sk, ip)
            if (ip == nil) then 
                print("NTP DNS fail!") 
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
    if file.exists("application.lua") then
        print("Running")
        -- the actual application is stored in 'application.lua'
        dofile("application.lua")
    else 
        print("application.lua deleted or renamed")
    end
end



ledstate = 1
function ledblink()
    if ledstate == 0 then
        gpio.write(led,gpio.LOW)
        ledstate = 1
    else
        gpio.write(led,gpio.HIGH)
        ledstate = 0
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
    print("You have two minutes to configure the AP")
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
            tmr.alarm(0, 120000, tmr.ALARM_SINGLE, function()  -- we have two minutes to configure
                rtctime.dsleep(10*60*1000000)
            end)
            getConfig()
        end
    else
        print("WiFi connection established, IP address: " .. wifi.sta.getip())
        startup()
    end
end)
