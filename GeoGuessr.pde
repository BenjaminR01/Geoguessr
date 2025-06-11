String apiKey = "AIzaSyDZO9a5ayFjj9t35D1ZbitJFLEshGvj_rs";
PImage streetViewImage;
PImage mapImage;

float heading = 0;
float pitch = 0;
float mouseSensitivity = 0.2;

float currentLat = 0;
float currentLng = 0;

volatile boolean locationReady = false;
volatile boolean cacheReady = false;

float cacheLat = 0, cacheLng = 0;

boolean viewChanged = true;
boolean mapOpen = false;
boolean showResult = false;

PVector guessCoord = null;
PVector guessPixel = null;
PVector actualPixel = null;
float distanceKm = 0;

// High Street View coverage regions: US, Canada, Europe, Japan, Taiwan, South Korea, Mexico, Chile, Argentina, South Africa, Australia, New Zealand
float[][] landRegions = {
  // USA and Canada
  {25, -125, 24, 60},    // US Lower 48 and Southern Canada
  {43, -80, 20, 35},     // Northern US, Southern Canada (Great Lakes, Ontario, Quebec)
  // Western Europe
  {35, -10, 25, 45},     // Spain, France, UK, Germany, Italy, etc.
  {55, 10, 15, 35},      // Scandinavia, Poland, etc.
  // Japan, Taiwan, South Korea
  {32, 128, 12, 15},     // Japan (all main islands)
  {23, 120, 3, 4},       // Taiwan
  {35, 126, 5, 4},       // South Korea
  // Australia, New Zealand
  {-39, 173, 6, 10},     // New Zealand
  {-38, 140, 12, 13},    // Southeastern Australia (Sydney/Melbourne/Adelaide)
  {-28, 114, 6, 18},     // Western Australia (Perth)
  // South America
  {-35, -72, 5, 10},     // Central Chile
  {-35, -63, 5, 6},      // Buenos Aires/Argentina
  {19, -103, 7, 16},     // Mexico
  // South Africa
  {-35, 17, 8, 16},      // South Africa
};

void setup() {
  size(1720, 920);
  frameRate(60);
  mapImage = loadImage("WorldMap.jpg");
  thread("preloadNextLocation");
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
      showResult = false;
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
      if (distanceKm <= 1000) {
        System.out.println("Wow, Amazing!");
      } else if (distanceKm <= 1800) {
        System.out.println("That's a pretty good guess!");
      } else if (distanceKm <= 2700) {
        System.out.println("Not bad.");
      } else if (distanceKm <= 4800) {
        System.out.println("Could've been worse...");
      } else {
        System.out.println("What are you doing???");
      }
    } else {
      println("Click on the map to guess first!");
    }
  }
  if (key == 'K' || key == 'k') {
    guessPixel = null;
    mapOpen = false;
    showResult = false;
    loadCachedLocation();
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
  String svURL = "https://maps.googleapis.com/maps/api/streetview?size=1720x920"
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

float[] pickWeightedLandRegion() {
  int index = int(random(landRegions.length));
  float[] region = landRegions[index];
  float lat = random(region[0], region[0] + region[2]);
  float lng = random(region[1], region[1] + region[3]);
  return new float[] {lat, lng};
}

void preloadNextLocation() {
  while (true) {
    float lat = 0, lng = 0;
    boolean found = false;
    int maxAttempts = 100;
    int attempts = 0;
    while (!found && attempts < maxAttempts) {
      float[] coords = pickWeightedLandRegion();
      lat = coords[0];
      lng = coords[1];
      if (isValidStreetViewLocation(lat, lng)) {
        found = true;
        break;
      }
      attempts++;
    }
    if (found) {
      cacheLat = lat;
      cacheLng = lng;
      cacheReady = true;
    } else {
      println("Failed to find valid location after " + maxAttempts + " attempts.");
      delay(2000);
    }
    while (cacheReady) delay(10);
  }
}

void loadCachedLocation() {
  if (cacheReady) {
    currentLat = cacheLat;
    currentLng = cacheLng;
    locationReady = true;
    viewChanged = true;
    cacheReady = false;
    println("Loaded location: " + currentLat + ", " + currentLng);
  } else {
    println("Location not ready yet! (should be rare)");
    locationReady = false;
  }
}
