var original_metadata_container;
var original_date_time_temp_container;

var clockTimer;
var metadataTimer;
var weatherTimer;
var transitionTimer;

var oldData;
var oldMedia = true;
var init = true;
var updating = false;

var layoutPos = 0;

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
    var jsonData = parseJSON(data);
    var media;
    var metadata_visibility = window.getComputedStyle(document.getElementById("metadata-container")).visibility
    
    if (jsonData.title == null && jsonData.artist == null && jsonData.album == null && jsonData.img == null) {
        media = false
    } else if (data != "{}" && metadata_visibility == "hidden") {
        if (updating == false){
            arrangeContent(true,true,true,true)
            updateWeather()
        }
    } else if (data != oldData) {
        
        if (jsonData.img == "") {
            jsonData.img = "png/cover_art_default.png"
        }
        
        document.getElementById("title").innerHTML = jsonData.title || "";
        document.getElementById("artist").innerHTML = jsonData.artist || "";
        document.getElementById("album").innerHTML = jsonData.album || "";
        document.getElementById("art").src = jsonData.img;
        media = true
        oldData = data
    }
    
    if (media == false && metadata_visibility != "hidden") {
        if (updating == false){
            arrangeContent(true,true,true,false)
            oldData = ""
        }
    }
    
    oldMedia = media
    //oldData = data
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
    var main_container = document.getElementById("main-container");
    var metadata_container = document.getElementById("metadata-container")
    var time_container = document.getElementById("time")
    var date_time_temp_container = document.getElementById("date-time-temp-container")
    var transition_time;
    
    updating = true
    setTimeout(() => {  updating = false; }, 3000);
    
    if (init == false) {
        transition_time = 0
        setTimeout(() => {  main_container.classList.toggle('fade'); }, 0);
        setTimeout(() => {  main_container.classList.toggle('fade'); }, 1700);
        transition_time = 1000
    } else {
        transition_time = 0
    }

    if (media == false) {
        
        setTimeout(() => {  metadata_container.innerHTML = ""; }, transition_time);
        setTimeout(() => {  metadata_container.appendChild(time_container); }, transition_time);
        setTimeout(() => {  swapStyleSheet("css/nomedia.css"); }, transition_time);
        oldData = ""
        
        
    } else {
        oldData = ""
        setTimeout(() => {  updateMetadata() }, transition_time+200);
        setTimeout(() => {  updateWeather() }, transition_time+200);
        setTimeout(() => {  date_time_temp_container.innerHTML = original_date_time_temp_container; }, transition_time);
        setTimeout(() => {  metadata_container.innerHTML = original_metadata_container; }, transition_time);
        setTimeout(() => {  swapStyleSheet("css/media.css") }, transition_time);
    }
}

function transitionLayout() {
    var main_container = document.getElementById("main-container");
    var metadata_container = document.getElementById("metadata-container");
    var date_time_temp_container = document.getElementById("date-time-temp-container");
    var pos;
    
    function switchPos(){
        if (layoutPos == 0) {
            setTimeout(() => {  metadata_container.after(date_time_temp_container); }, 1200);
            pos = 1;
        } else if (layoutPos == 1) {
            setTimeout(() => {  date_time_temp_container.after(metadata_container); }, 1200);
            pos = 0;
        }
    }
    setTimeout(() => {  main_container.classList.toggle('fade'); }, 0);
    switchPos();
    setTimeout(() => {  main_container.classList.toggle('fade'); }, 1500);
    
    layoutPos = pos;
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

function swapStyleSheet(sheet) {
    document.getElementById("layout-stylesheet").setAttribute("href", sheet);  
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
    transitionTimer = setInterval('transitionLayout()',300000)
    
    setTimeout(() => {  init = false; }, 3000);
}