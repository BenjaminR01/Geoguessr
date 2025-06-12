String apiKey = "AIzaSyDZO9a5ayFjj9t35D1ZbitJFLEshGvj_rs";
PImage streetViewImage, mapImage;
float heading = 0, pitch = 0, mouseSensitivity = 0.2;
float currentLat = 0, currentLng = 0, nextLat = 0, nextLng = 0;
boolean locationReady = false, viewChanged = true, mapOpen = false, showResult = false, guessMade = false;
PVector guessCoord, guessPixel, actualPixel;
float distanceKm = 0;

float[][] landRegions = { 
  {25, -125, 24, 60}, {43, -80, 20, 35}, {35, -10, 25, 45}, {55, 10, 15, 35},
  {32, 128, 12, 15}, {23, 120, 3, 4}, {35, 126, 5, 4}, {-39, 173, 6, 10},
  {-38, 140, 12, 13}, {-28, 114, 6, 18}, {-35, -72, 5, 10}, {-35, -63, 5, 6},
  {19, -103, 7, 16}, {-35, 17, 8, 16},
}; // Coordinates for general landmasses

void setup() {
  size(1720, 860);
  frameRate(60);
  mapImage = loadImage("WorldMap.jpg");
  preloadNextValidLocation();
  currentLat = nextLat;
  currentLng = nextLng;
  heading = random(0, 360);
  locationReady = true;
  viewChanged = true;
  preloadNextValidLocation();
  println("Location loaded: " + currentLat + ", " + currentLng);
}

void draw() {
  background(255);
  if (!locationReady) {
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Loading location...", width / 2, height / 2);
    return;
  }

  if (viewChanged) {
    loadStreetViewImage();
    viewChanged = false;
  }

  // Draw Street View on the left
  if (streetViewImage != null) {
    image(streetViewImage, 0, 0, 860, 860);
  } else {
    fill(0);
    textSize(20);
    text("Street View Image not available", 20, 40);
  }

  // Draw map on the right
  image(mapImage, 860, 0, 860, 860);
  if (guessPixel != null) {
    fill(255, 0, 0);
    stroke(0);
    ellipse(guessPixel.x + 860, guessPixel.y, 12, 12);
  }
  if (showResult && actualPixel != null) {
    fill(0, 200, 255);
    ellipse(actualPixel.x + 860, actualPixel.y, 12, 12);
    stroke(0);
    line(guessPixel.x + 860, guessPixel.y, actualPixel.x + 860, actualPixel.y);
    fill(0);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Distance: " + nf(distanceKm, 1, 2) + " km", 870, 10);
  }
}

void keyPressed() {
  if (key == 'g' || key == 'G') { // Inputs the guess
    if (guessCoord != null && locationReady) {
      distanceKm = haversine(currentLat, currentLng, guessCoord.x, guessCoord.y); // Get distance using haversine
      showResult = true;
      actualPixel = latLngToPixel(currentLat, currentLng);
      guessMade = true;
      println("Nice try!");
      println("Your guess: " + guessCoord.x + ", " + guessCoord.y);
      println("Actual location: " + currentLat + ", " + currentLng);
      println("Distance: " + nf(distanceKm, 1, 2) + " km");
    } else {
      println("Click on the map to guess first!");
    }
  }
  if (key == 'k' || key == 'K') {
    if (guessMade) { // Generates new location if guess has been made
      guessCoord = guessPixel = actualPixel = null;
      showResult = guessMade = false;
      loadNextLocation();
      preloadNextValidLocation();
    } else {
      println("You must make a guess before moving to the next location!");
    }
  }
}

void mousePressed() {
  // Only register clicks on map side (right half)
  if (mouseX >= 860 && locationReady) {
    float mapX = mouseX - 860;
    float mapY = mouseY;
    guessPixel = new PVector(mapX, mapY);
    guessCoord = pixelToLatLng(mapX, mapY);
    println("Guessed lat/lng: " + guessCoord);
  }
}

void mouseDragged() {
  if (mouseX < 860 && locationReady) { // Changes POV of observer
    heading -= (mouseX - pmouseX) * mouseSensitivity;
    pitch += (mouseY - pmouseY) * mouseSensitivity;
    viewChanged = true;
  }
}

void loadStreetViewImage() {
  pitch = constrain(pitch, -90, 90);
  String svURL = "https://maps.googleapis.com/maps/api/streetview?size=860x860"
    + "&location=" + currentLat + "," + currentLng
    + "&heading=" + heading
    + "&pitch=" + pitch
    + "&key=" + apiKey
    + "&foo=.jpg";
  try {
    streetViewImage = loadImage(svURL);
  } catch (Exception e) {
    streetViewImage = null;
  }
}

void preloadNextValidLocation() { // Loads the next image while the player is inputting a guess. This will save time.
  int maxAttempts = 1500;
  float minDistanceKm = 50;
  for (int i = 0; i < maxAttempts; i++) {
    float[] coords = pickWeightedLandRegion();
    float lat = coords[0], lng = coords[1];
    float dist = haversine(currentLat, currentLng, lat, lng);
    if (isValidStreetViewLocation(lat, lng) && dist >= minDistanceKm) {
      nextLat = lat;
      nextLng = lng;
      println("Next location ready: " + nextLat + ", " + nextLng);
      return;
    }
  }
  nextLat = nextLng = 0;
}

void loadNextLocation() {
  if (nextLat != 0 && nextLng != 0) {
    currentLat = nextLat;
    currentLng = nextLng;
    heading = random(0, 360);
    pitch = 0;
    locationReady = true;
    viewChanged = true;
    println("Location loaded: " + currentLat + ", " + currentLng);
  }
}

float[] pickWeightedLandRegion() {
  int index = int(random(landRegions.length)); // Picks location from a certain region
  float[] region = landRegions[index];
  float lat = random(region[0], region[0] + region[2]);
  float lng = random(region[1], region[1] + region[3]);
  return new float[] {lat, lng};
}

boolean isValidStreetViewLocation(float lat, float lng) {
  String url = "https://maps.googleapis.com/maps/api/streetview/metadata?location=" + lat + "," + lng + "&key=" + apiKey;
  try {
    JSONObject metadata = loadJSONObject(url);
    if (metadata != null) {
      return metadata.getString("status").equals("OK");
    }
  } catch (Exception e) {}
  return false;
}

PVector pixelToLatLng(float x, float y) { // Converts pixel units to latitude and longitude
  float lng = map(x, 0, 860, -180, 180);
  float lat = map(y, 860, 0, -90, 90);
  return new PVector(lat, lng);
}

PVector latLngToPixel(float lat, float lng) { // Other conversion
  float x = map(lng, -180, 180, 0, 860);
  float y = map(lat, -90, 90, 860, 0);
  return new PVector(x, y);
}

float haversine(float lat1, float lon1, float lat2, float lon2) { // Uses a special formula to calculate distance (due to the Earth being a sphere)
  float R = 6371;
  float dLat = radians(lat2 - lat1);
  float dLon = radians(lon2 - lon1);
  float a = sin(dLat / 2) * sin(dLat / 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}
