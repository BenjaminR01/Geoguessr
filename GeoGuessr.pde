//WIP
String apiKey = "AIzaSyDZO9a5ayFjj9t35D1ZbitJFLEshGvj_rs"; //api key to grab images from google street view
PImage streetViewImage; //street view Image variable
PImage mapImage; //map image variable.

float heading = 0; //x- direction 
float pitch = 0; //y- direction
float mouseSensitivity = 0.2; //mouse sensitivity (CAN CHANGE)

float currentLat = 0; //stores LAT coords
float currentLng = 0; //stores LONG coords

 boolean locationReady = false; //bool value to determine if the sketch has the next location
 float nextLat, nextLng; //the next location coords

boolean viewChanged = true; //view change bool val
boolean mapOpen = false; //if map is open val
boolean showResult = false;

PVector guessCoord = null;
PVector guessPixel = null;
PVector actualPixel = null;
float distanceKm = 0;

void setup() {
  size(800, 600);
  frameRate(1200);
  mapImage = loadImage("WorldMap.jpg");
  thread("prepareNextRandomLocation"); // Start random location loader
}

void draw() {
  background(255);

  if (!locationReady) {
    // Loading screen
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Loading location...", width / 2, height / 2);
    return;
  }

  if (mapOpen) {
    image(mapImage, 0, 0, width, height);

    if (guessPixel != null) {
      fill(255, 0, 0);
      stroke(0);
      ellipse(guessPixel.x, guessPixel.y, 12, 12);
    }

    if (showResult && actualPixel != null) {
      fill(0, 200, 255);
      ellipse(actualPixel.x, actualPixel.y, 12, 12);

      stroke(0);
      line(guessPixel.x, guessPixel.y, actualPixel.x, actualPixel.y);

      fill(0);
      textSize(16);
      textAlign(LEFT, TOP);
      text("Distance: " + nf(distanceKm, 1, 2) + " km", 10, 10);
    }

    return;
  }

  if (viewChanged) {
    loadStreetViewImage();
    viewChanged = false;
  }

  if (streetViewImage != null) {
    image(streetViewImage, 0, 0);
  } else {
    fill(0);
    textSize(20);
    text("Street View Image not available", 20, 40);
  }
}

void keyPressed() {
  if (key == 'm' || key == 'M') {
    mapOpen = !mapOpen;
    if (!mapOpen) {
      showResult = false; // Hide results when returning to street view
    }
  }

  if (key == 'g' || key == 'G') {
    if (guessCoord != null && locationReady) {
      distanceKm = haversine(currentLat, currentLng, guessCoord.x, guessCoord.y);
      showResult = true;
      actualPixel = latLngToPixel(currentLat, currentLng);
      println("Guessed: " + guessCoord.x + ", " + guessCoord.y);
      println("Actual: " + currentLat + ", " + currentLng);
      println("Distance: " + nf(distanceKm, 1, 2) + " km");
      if (distanceKm <= 1000){
        System.out.println("Wow, Amazing!");
      }
      else if (distanceKm <= 1800){
        System.out.println("That's a pretty good guess!");
      }
      else if (distanceKm <= 2700){
        System.out.println("Not bad.");
      }
      else if (distanceKm <= 4800){
        System.out.println("Could've been worse...");
      }
      else{
        System.out.println("What are you doing???");
      }
    } else {
      println("Click on the map to guess first!");
    }
  }
  
  if(key == 'K' || key == 'k') {
    System.out.println("Loading Image...");
    locationReady = false;
    guessPixel = null;
    mapOpen = false;
    showResult = false;
    prepareNextRandomLocation();
  }

}

void mousePressed() {
  if (mapOpen && locationReady) {
    guessPixel = new PVector(mouseX, mouseY);
    guessCoord = pixelToLatLng(mouseX, mouseY);
    println("Guessed lat/lng: " + guessCoord.x + ", " + guessCoord.y);
  }
}

void mouseDragged() {
  if (!mapOpen && locationReady) {
    float dx = (mouseX - pmouseX) * mouseSensitivity;
    float dy = (mouseY - pmouseY) * mouseSensitivity;

    heading -= dx;
    pitch += dy;
    viewChanged = true;
  }
}

void loadStreetViewImage() {
  pitch = constrain(pitch, -90, 90);

  String svURL = "https://maps.googleapis.com/maps/api/streetview?size=800x600"
    + "&location=" + currentLat + "," + currentLng
    + "&heading=" + heading
    + "&pitch=" + pitch
    + "&key=" + apiKey;

  try {
    streetViewImage = loadImage(svURL + "&format=png", "png");
  } catch (Exception e) {
    println("Error loading Street View image: " + e.getMessage());
    streetViewImage = null;
  }
}

PVector pixelToLatLng(float x, float y) {
  float lng = map(x, 0, width, -180, 180);
  float lat = map(y, height, 0, -90, 90);
  return new PVector(lat, lng);
}

PVector latLngToPixel(float lat, float lng) {
  float x = map(lng, -180, 180, 0, width);
  float y = map(lat, -90, 90, height, 0);
  return new PVector(x, y);
}

float haversine(float lat1, float lon1, float lat2, float lon2) {
  float R = 6371;
  float dLat = radians(lat2 - lat1);
  float dLon = radians(lon2 - lon1);
  float a = sin(dLat / 2) * sin(dLat / 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * sin(dLon / 2) * sin(dLon / 2);
  float c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

boolean isValidStreetViewLocation(float lat, float lng) {
  String metadataURL = "https://maps.googleapis.com/maps/api/streetview/metadata?"
    + "location=" + lat + "," + lng
    + "&key=" + apiKey;

  try {
    JSONObject metadata = loadJSONObject(metadataURL);
    if (metadata != null) {
      return metadata.getString("status").equals("OK");
    }
  } catch (Exception e) {
    println("error: " + e.getMessage());
  }
  return false;
}

void prepareNextRandomLocation() {
  int attempts = 0;
  while (attempts < 1500) {
    float lat = random(-60, 60);
    float lng = random(-180, 180);
    if (isValidStreetViewLocation(lat, lng)) {
      currentLat = lat;
      currentLng = lng;
      locationReady = true;
      viewChanged = true;
      System.out.println("Attempts to load image:" + attempts);
      println("Loaded random location: " + currentLat + ", " + currentLng);
      return;
    }
    attempts++;
  }
  println("Failed to find a valid location.");
}
