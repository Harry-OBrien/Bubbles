import peasy.*;

class Scene {
  PeasyCam cam;
  private int cubeSize;

  Scene(PApplet parent, int cubeSize) {
    this.cam = new PeasyCam(parent, 0, 0, 250, 500);
    cam.setMaximumDistance(1200);
    cam.setMinimumDistance(50);
    cam.setWheelScale(0.3);
    
    this.cubeSize = cubeSize;
  }

  void update() {
  }

  void show() {
    // Environment
    fill(255);
    background(132, 151, 184);
    lights();

    // Draw the floor
    drawFloor();
    drawHUD();
  }

  private void drawFloor() {
    pushMatrix();
    translate(0, 0, 0);
    strokeWeight(2);
    stroke(0);
    rect(0, 0, cubeSize, cubeSize);
    popMatrix();
  }

  void drawHUD() {
    cam.beginHUD();
    fill(0);
    text(frameRate, 25, height - 25);
    cam.endHUD();
  }
}
