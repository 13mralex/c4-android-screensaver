local HTTPPORT = 8089

args = {}
args["title"] = "none"
args["album"] = "none"
args["artist"] = "none"
projectJson = ""

function OnDriverDestroyed()
   -- Kill all timers in the system...
   if (gDbgTimer ~= 0) then gDbgTimer = C4:KillTimer(gDbgTimer) end

   -- Remove Server Socket...
   C4:DestroyServer()
end



function OnPropertyChanged(strProperty)
   local prop = Properties[strProperty]

   if (strProperty == "Debug Mode") then
      if (gDbgTimer > 0) then gDbgTimer = C4:KillTimer(gDbgTimer) end
      g_dbgprint, g_dbglog = (prop:find("Print") ~= nil), (prop:find("Log") ~= nil)
      if (prop == "Off") then
         return
      end
      gDbgTimer = C4:AddTimer(300, "MINUTES")
      dbg("Debug Timer set to 300 Minutes (" .. math.floor((290 / 60) + .5) .. " hours)")
      return
   end
end



function dbg(strDebugText)
   if (g_dbgprint) then print(strDebugText) end
   C4:DebugLog("\r\nWeb Event: " .. strDebugText)
end



function ExecuteCommand(strCommand, tParams)
   tParams = tParams or {}

   dbg("ExecuteCommand: " .. strCommand)
   for k,v in pairs(tParams) do dbg("" .. k .. ":" .. v) end

   if (strCommand == "LUA_ACTION") then
      if (tParams.ACTION == "DEFAULT_ACTION") then
         dbg("Default Action")
      end
   end
end



function OnTimerExpired(idTimer)
   if (idTimer == gDbgTimer) then
      dbg("Turning Debug Mode Off (timer expired)")
      C4:UpdateProperty("Debug Mode", "Off")
      OnPropertyChanged("Debug Mode")
      gDbgTimer = C4:KillTimer(gDbgTimer)
   end
   if (idTimer == gInitTimer) then
      MyDriverInit()
      gInitTimer = C4:KillTimer(gInitTimer)
   end
end



function MyDriverInit()
   if (gInitialized ~= nil) then return end  -- Ensure we don't call OnDriverInit multiple times
   gInitialized = true
   dbg("MyDriverInit()")

   C4:CreateServer(HTTPPORT)
   C4:AddVariable("COMMAND", "", "STRING")

   dbg("Initialization Complete.")
end


function OnDriverLateInit()
    MyDriverInit()
end



function UnURLEscapeHTTP(strURLEscaped)
   temp = string.gsub(strURLEscaped, " ", "%%20")
   return temp
end



-- ParseStatus parses requests received on port 8080...
function ParseStatus()
   --dbg("Received: " .. gRecvBuf)

   -- Parse for events sent from web client, set variable and fire event...
   local _, _, url = string.find(gRecvBuf, "GET /(.*) HTTP")
   url = url or ""
   gCmd = url
   if (string.len(url) > 0) then
      dbg("GET URL: [" .. url .. "]")
      C4:SetVariable("COMMAND", url)
      C4:FireEvent("Command Received")
   else
      dbg("No Command Received.")
      gCmd = "None"
   end
end

-----------------------------------------------------
--------------- OTHER FUNCTIONS --------------
-----------------------------------------------------


function GetWebFile(url,content_type,nHandle)
   print ("---Getting file: "..url.."---")
   url = C4:GetControllerNetworkAddress().."/c4z/Metadata_Webserver/www/"..url
   dbg("URL: "..url)
   C4:urlGet(url, {}, false,
   function(ticketId, strData, responseCode, tHeaders, strError)
      if (strError == nil) then
         print("UrlGet Success")
         headers = GetHeaders(content_type,strData)
         C4:ServerSend(nHandle,  headers .. strData)
         C4:ServerCloseClient(nHandle)
      else
         print("C4:urlGet() failed: "..strError)
      end
   end
   )
end

function GetRoomMedia(roomId)
  local args = {}
  local deviceIconUrl = ""
  local roomMediaXml = C4:GetVariable(tonumber(roomId),1031)
  local roomMedia = C4:ParseXml(roomMediaXml)
  if (roomMedia) then
     for i,v in pairs(roomMedia.ChildNodes) do
        args[v["Name"]] = v.Value or ""
     end

     local deviceInfoXml = C4:GetDeviceData(tonumber(args["deviceid"]))
     deviceInfoXml = "<data>"..deviceInfoXml.."</data>"
     local deviceInfo = C4:ParseXml(deviceInfoXml)
     local ip = C4:GetControllerNetworkAddress()

     --Locate Display Icons
     for i1,v1 in pairs(deviceInfo.ChildNodes) do
      if(v1.Name == "capabilities") then
        for i2,v2 in pairs(deviceInfo.ChildNodes[i1].ChildNodes) do
           if (v2.Name == "navigator_display_option") then
             for i3,v3 in pairs(deviceInfo.ChildNodes[i1].ChildNodes[i2].ChildNodes) do
              if (v3.Name == "display_icons") then
                --for i4,v4 in pairs(deviceInfo.ChildNodes[i1].ChildNodes[i2].ChildNodes[i3].ChildNodes) do
                --  print("Index: "..i4.."URL: "..v4.Value)
                --end
                deviceIconUrl = deviceInfo.ChildNodes[i1].ChildNodes[i2].ChildNodes[i3].ChildNodes[1].Value
                --print("Final URL: "..deviceIconUrl)
              end
             end
           end
        end

      end
       --print("---")
       --print("name: "..v.Name.."\nvalue: "..v.Value.."\nChildNodes: "..C4:JsonEncode(v.ChildNodes))
       --deviceDataArr[v["Name"]] = v.ChildNodes or ""
     end

     args["devicename"] = C4:ListGetDeviceName(args["deviceid"]) or ""

     if (args["img"] == nil) then
      local prefix,path = deviceIconUrl:match("(.+)://(.+)")
      local basePath,fileName = path:match("(.+)/(.+)")

      local imgUrl = "http://"..ip.."/"..basePath.."/experience_1024.png"
      local imgUrlFallback = "http://"..ip.."/"..path

      args["img"] = imgUrl
      args["imgFallback"] = imgUrlFallback
     else
      local imgUrl = C4:Base64Decode(args["img"])
      local prefix,path = imgUrl:match("(.+)://(.+)")
      if (prefix == "controller") then
        imgUrl = "http://"..ip.."/"..path
      end
      args["img"] = imgUrl
     end

  end

  return args
end

function GetHeaders(ContentType,msg)
   res = "HTTP/1.1 200 OK\r\nContent-Length: " .. msg:len() .. "\r\nContent-Type: "..ContentType.."\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
   return res
end

-----------------------------------------------------
--------------- SERVER SOCKET (feedback) --------------
-----------------------------------------------------
function OnServerConnectionStatusChanged(nHandle, nPort, strStatus)
   --dbg("OnServerConnectionStatusChanged[" .. nHandle .. " / " .. nPort .. "]: " .. strStatus)
end



function OnServerDataIn(nHandle, strData)
   --dbg("OnServerDataIn: " .. strData)
   msg = ""
   headers = ""
   args2 = {}
   gRecvBuf = strData
   local ret, err = pcall(ParseStatus)
   if (ret ~= true) then
      local e = "Error Parsing return status: " .. err
      print(e)
      C4:ErrorLog(e)
   end
   gRecvBuf = ""

   urlArgs = {}

   for i in string.gmatch(gCmd, "[^/]+") do
      urlArgs[#urlArgs+1] = i
   end
   print("If starting...")
   if tonumber(gCmd) then
      print("else reached")
      roomId = gCmd
      res = GetRoomMedia(roomId)
      msg = GetMainHtml(res)

      GetWebFile("html/main.html","html",nHandle)
   elseif (urlArgs[2] == "json") then
      --print("Elseif match 1...")
      roomId = urlArgs[1]
      res = GetRoomMedia(roomId)
      msg = C4:JsonEncode(res)
      headers = GetHeaders("text/json",msg)

      C4:ServerSend(nHandle,  headers .. msg)
      C4:ServerCloseClient(nHandle)
   elseif (gCmd == "project") then
      --print("Elseif match 2...")
      msg = projectJson
      headers = GetHeaders("text/json",msg)

      C4:ServerSend(nHandle,  headers .. msg)
      C4:ServerCloseClient(nHandle)
   elseif (urlArgs[1] == "png") then
      GetWebFile(gCmd,"image/png",nHandle)
   else
      --print("Else reached..")
      GetWebFile(gCmd,"text/"..urlArgs[1],nHandle)
   end

   --C4:ServerSend(nHandle,  headers .. msg)
   --C4:ServerCloseClient(nHandle)
end

--MainHtmlFile = C4:

function GetMainHtml(args1)

   if (args1["title"] == nil) then
      args1["title"] = ""
   elseif (args1["artist"] == nil) then
      args1["artist"] = ""
   elseif (args1["album"] == nil) then
      args1["album"] = ""
   end

   mainHtml = [[

   <!doctype html>
   <html>
   <head>
   <meta charset="UTF-8">
   <title>C4-Android-Screensaver</title>
   <script type="text/javascript" src="metadata.js"></script>
   <link href="style.css" rel="stylesheet" type="text/css">
   <link rel="preconnect" href="https://fonts.googleapis.com">
   <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
   <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@100;300&display=swap" rel="stylesheet">
   </head>

   <body onLoad="populateMetadata()">
   <div id="main-container">
   <div id="date-time-temp-container">
   <div id="time">
   <span class="text" id="clock"></span>
   <span class="text" id="ampm"></span>
   </div>
   <div id="date">
   <span class="text" id="dayofweek"></span>
   <span class="text" id="day"></span>
   <span class="text" id="month"></span>
   </div>
   <div id="temp">
   <span class="text" id="temp-num"></span>
   <span class="text" id="scale"></span>
   </div>
   </div>
   <div id="metadata-container">

   <div id="art-container">
   <img id="art" src="" alt=""/>
   </div>

   <div id="metadata-text-container">
   <span id="album" class="text"></span>
   <span id="artist" class="text"></span>
   <span id="title" class="text"></span>
   </div>

   </div>
   </div>
   </body>
   </html>

   ]]

   return mainHtml

end


mainCss = [[


body {
   background-color: black;
   /* background-image: url("template.png"); */
   /* background-size: 100% 100%; */
   background-repeat: no-repeat;
   overflow: hidden;
   width: 100%;
   height: 100%;
   margin:0;
   padding:0;
}

#main-container {
   display: flex;
   align-items: center;
   justify-content: center;
   height: 100vh;
   /* margin-left: 1%; */
   /* gap: 1%; */
   /* margin-right: 3%; */
}

#metadata-container {
   display: flex;
   flex-direction: column;
   justify-content: center;
   height: 100vh;
   width: 66vw;
   margin-right: 3%;
}

#date-time-temp-container {
   width: 33vw;
   display: flex;
   flex-direction: column;
   gap: 13.5vmin;
   /* align-items: center; */
   justify-content: center;
   margin-left: 3%;
   height: 100%;
   margin-top: 2vh;
}

#time, #date, #temp {
   display: flex;
   flex-direction: column;
   align-items: center;
   gap: 3.5vmin;
   line-height: 4.5vmin;
   /* margin-top: 3vh; */
}

#metadata-text-container {
   display: flex;
   flex-direction: column-reverse;
   align-items: center;
   /* height: 25%; */
   margin-bottom: 10%;
   margin-top: 5.5vmin;
   gap: 1vh;
   text-align: center;
}

#art-container{
   /* height: 60vh; */
   margin-top: 24.5vmin;
   display: flex;
   /* vertical-align: baseline; */
   flex-direction: column;
   flex-wrap: wrap;
   align-content: center;
}

#art {
   position: relative;
   width: 40vmin;
   height: 40vmin;
   /* border: solid; */
   /* border-color: white; */
   /* opacity: 50%; */
}

.text {
   color: white;
   font-size: 3.5vw;
   font-family: "Roboto";
   font-weight: 100;
}

#clock, #day, #temp-num {
   font-size: 12vmin;
}

#ampm, #dayofweek, #month, #scale {
   font-size: 3.5vmin;
}

#temp, #time {
   margin-top: 4vmin;
}

#title {
   font-size: 6.9vmin;
}

#artist, #album {
   font-size: 5.35vmin;
}

#title, #artist, #album {
   font-weight: 300;
}


]]

mainJs = [[

var original_metadata_container;
var original_date_time_temp_container;

var clockTimer;
var metadataTimer;
var weatherTimer;

var oldData;

function updateClock() {

   var date = new Date()

   var hours = date.getHours();
   var minutes = date.getMinutes();
   var days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
   var dayName = days[date.getDay()];
   var dayNum = date.getDate();
   var months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
   var monthName = months[date.getMonth()];
   var ampm = hours >= 12 ? 'PM' : 'AM';
   hours = hours % 12;
   hours = hours ? hours : 12; // the hour '0' should be '12'
   minutes = minutes < 10 ? '0'+minutes : minutes;

   var clock = hours + ':' + minutes;

   document.getElementById("clock").innerHTML = clock;
   document.getElementById("ampm").innerHTML = ampm;
   document.getElementById("dayofweek").innerHTML = dayName;
   document.getElementById("day").innerHTML = dayNum;
   document.getElementById("month").innerHTML = monthName;

}

function updateMetadata() {
   var url = window.location.href;
   var data = urlCall(url+"/json")

   if (data == "{}") {
      arrangeContent(true,true,true,false)
   } else if (data != oldData) {
   arrangeContent(true,true,true,true)

   data = parseJSON(data);
   document.getElementById("title").innerHTML = data.title || "";
   document.getElementById("artist").innerHTML = data.artist || "";
   document.getElementById("album").innerHTML = data.album || "";
   document.getElementById("art").src = data.img;
}

oldData = data
}

function updateWeather() {
var projectData = urlCall("project")
projectData = parseJSON(projectData)

var lat = projectData.latitude
var long = projectData.longitude

var weatherUrl1 = "https://api.weather.gov/points/"+lat+","+long
var weatherData1 = parseJSON(urlCall(weatherUrl1))

var weatherUrl2 = weatherData1.properties.forecastHourly
var weatherData2 = parseJSON(urlCall(weatherUrl2))

var temp = weatherData2.properties.periods[0].temperature

var scale = "F"

if (projectData.scale == "CELSIUS") {
   temp = (temp -32) * 5/9
   scale = "C"
}

temp = Math.round(temp)

document.getElementById("temp-num").innerHTML = temp;
document.getElementById("scale").innerHTML = scale;
}

function arrangeContent(time,date,weather,media) {
var metadata_container = document.getElementById("metadata-container")
var time_container = document.getElementById("time")
var date_time_temp_container = document.getElementById("date-time-temp-container")

if (media == false) {
   metadata_container.innerHTML = "";
   metadata_container.appendChild(time_container);
   document.getElementById("clock").style.fontSize = "30vmin";
   document.getElementById("ampm").style.fontSize = "12vmin";
   document.getElementById("time").style.gap = "15vmin";
   document.getElementById("metadata-container").style.marginTop = "5vmin";

} else {
date_time_temp_container.innerHTML = original_date_time_temp_container;
metadata_container.innerHTML = original_metadata_container;
document.getElementById("clock").style = "";
document.getElementById("ampm").style = "";
document.getElementById("time").style = "";
document.getElementById("metadata-container").style = "";
}
}

function urlCall(url) {
var xmlHttp = new XMLHttpRequest();
xmlHttp.open( "GET", url, false ); // false for synchronous request
xmlHttp.send( null );
return xmlHttp.responseText;
}

function parseJSON(json) {
return JSON.parse(json)
}

function populateMetadata() {
original_metadata_container = document.getElementById("metadata-container").innerHTML;
original_date_time_temp_container = document.getElementById("date-time-temp-container").innerHTML

updateClock()
updateMetadata()
updateWeather()
clockTimer = setInterval('updateClock()',1000)
metadataTimer = setInterval('updateMetadata()',1000)
weatherTimer = setInterval('updateWeather()',300000)
}

]]

----------------------------------------------------------------------------------------------------------
------------------------------------------------  Modules  -------------------------------------------------
----------------------------------------------------------------------------------------------------------

print("Driver Loaded..." .. os.date())

project = {}


-----------------------------------------------------
------------------------ INIT ------------------------
-----------------------------------------------------

function OnDriverLateInit()
print("Driver late init...")

function get(data,name)
return data:match("<"..name..">(.-)</"..name..">")
end


projectInfo = C4:GetProjectItems()

projectInfo = get(projectInfo,"itemdata")
projectInfo = "<itemdata>"..projectInfo.."</itemdata>"
projectInfo = C4:ParseXml(projectInfo)

project = {}

for i,v in pairs(projectInfo["ChildNodes"]) do
project[v["Name"]] = v.Value
end

projectJson = C4:JsonEncode(project)

--print(projectJson)

end

gRecvBuf = ""
gDbgTimer = 0
gCmd = ""

OnPropertyChanged("Debug Mode")
gInitTimer = C4:AddTimer(5, "SECONDS")

