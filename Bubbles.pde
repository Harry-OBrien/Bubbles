 //<>//
private int cubeSize = 500;

Scene scene;
ParticleSystem sys;

void setup() {
  // Environment settings
  fullScreen(P3D);
  pixelDensity(2);
  //noCursor();
  frameRate(30);
  rectMode(CENTER);

  // Entities
  scene = new Scene(this, cubeSize);
  sys = new ParticleSystem(cubeSize, 10, 0.4);
}

void draw() {
  // Update system
  scene.update();
  sys.update();

  // Draw everything
  scene.show();
  sys.show();
}
