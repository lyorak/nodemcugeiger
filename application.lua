print("application started")

dofile("adafruit_creds.lua")
--mqtt_username = ""
--mqtt_password = ""
--mqtt_feedname_geiger = "g001"
--mqtt_feedname_vbat = "vbat"

-- init mqtt client with keepalive timer 120sec
m = mqtt.Client("Geiger", 200, mqtt_username, mqtt_password)

m:on("connect", function(client) print ("connected") end)
m:on("offline", function(client) print ("offline") end)


-- on publish message receive event
--m:on("messages", function(client, topic, data) 
--    print(topic .. ":" ) 
--    if data ~= nil then
--        print(data)
--    end
--end)

function goSleep()
    print("Now should be sleeping...")
    gpio.write(4,gpio.HIGH)
    --rtctime.dsleep_aligned(10*60*1000000,8*60*1000000)
end

function publishToAdaIOCPM(cpm)
    m:publish(mqtt_username .. "/feeds/" .. mqtt_feedname_geiger,cpm,0,0,publishToAdaIOVbat) 
end

function publishToAdaIOVbat()
    m:publish(mqtt_username .. "/feeds/" .. mqtt_feedname_vbat,adc.readvdd33(0),0,0,goSleep)
end

cpm = rtcmem.read32(10)

function onConnected(client)
    print("Connected")
    cpm = cpm + 1
    print("publishing data ...")
    publishToAdaIOCPM(cpm)
    rtcmem.write32(10,cpm)
end

function onFailed(client,reason)
    print("failed reason: "..reason)
    tmr.delay(1000)
    goSleep()
end

m:connect("io.adafruit.com", 8883, 1, onConnected, onFailed)

