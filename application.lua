print("application started")

dofile("adafruit_creds.lua")

scl_pin = 1
sda_pin = 2
i2c_addr = 0xa2/2

-- initialize i2c
i2c.setup(0, sda_pin, scl_pin, i2c.SLOW)


-- user defined function: read from reg_addr content of dev_addr len x bytes
function i2cReadReg(dev_addr, reg_addr,len)
    print("dev_addr: " .. dev_addr)   
    i2c.start(0)
    i2c.address(0, dev_addr, i2c.TRANSMITTER)
    i2c.write(0, reg_addr)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, dev_addr, i2c.RECEIVER)
    c = i2c.read(0, len)
    i2c.stop(0)
    return c
end


-- user defined function: write  from reg_addr content of dev_addr
function i2cWriteReg(dev_addr, reg_addr, data)
    i2c.start(0)
    i2c.address(0, dev_addr, i2c.TRANSMITTER)
    i2c.write(0, reg_addr)
    i2c.write(0, data)
    i2c.stop(0)
end


function readAndResetCounter()
    counter = i2cReadReg(i2c_addr,1,3)
    i2cWriteReg(i2c_addr,0,0xa0) -- event counter mode, reset     
    i2cWriteReg(i2c_addr,1,{0,0,0}) -- 0 to counter     
    
    i2cWriteReg(i2c_addr,0,0x20) -- event counter mode, start counting

    fixed = counter:gsub("(.)(.)", "%2%1")
    print("Received count value: 0 " .. string.byte(counter,1))
    print("Received count value: 1 " .. string.byte(counter,2))
    print("Received count value: 2 " .. string.byte(counter,3))
    print("Fixed: " .. fixed)
    return fixed
end
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
    --cpm = cpm + 1
    cpm = readAndResetCounter()
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

