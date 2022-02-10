 //<>//
private int cubeSize = 500;

Scene scene;
ParticleSystem sys;

void setup() {
  // Environment settings
  size(600, 400, P3D);
  //fullScreen(P3D);
  pixelDensity(2);
  //noCursor();
  //frameRate(1000);
  rectMode(CENTER);
  smooth(8);
  
  randomSeed(0);

  // Entities
  scene = new Scene(this, cubeSize);
  sys = new ParticleSystem(this, scene, cubeSize, 0.4, 0);
}

// TODO: Look at writing a compute shader for calculating the mesh
float offset = PI/4;
void draw() {
  pushMatrix();
  rotateX(PI/3);
  rotateZ(offset);
  translate(0, 0, -150);
  offset += PI/1000;
  // Update system
  scene.update();
  sys.update();

  // Draw everything
  scene.show();
  sys.show();
  popMatrix();
}
