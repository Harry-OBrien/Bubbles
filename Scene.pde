import peasy.*;
import controlP5.*;

class Scene {
  private PeasyCam cam;
  private ControlP5 cp5;
  private Slider grav, fric;  // environment vars
  private Slider res, meshSize; // Rendering vars
  private Slider attractionDistance, velocityLimit;  // particle vars

  private Toggle showParticles;

  private int cubeSize;

  Scene(PApplet parent, int cubeSize) {
    this.cam = new PeasyCam(parent, 0, 0, 250, 500);
    cam.setMaximumDistance(1200);
    cam.setMinimumDistance(50);
    cam.setWheelScale(0.3);

    this.cp5 = new ControlP5(parent);
    grav = cp5.addSlider("gravity", 0, 300, 100, 10, 10, 200, 20) // (label, min, max, starting, x, y, width, height)
      .setColorActive(color(128, 0, 0))
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setLabelVisible(true);

    fric = cp5.addSlider("friction", 0, 300, 100, 10, 40, 200, 20)
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setLabelVisible(true);

    res = cp5.addSlider("fieldResolution", 4, 50, 9, 10, 70, 200, 20)
      .setColorActive(color(128, 0, 0))
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setNumberOfTickMarks(47)
      .setLabelVisible(true);

    meshSize = cp5.addSlider("meshSize", 0, 300, 100, 10, 100, 200, 20)
      .setColorActive(color(128, 0, 0))
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setLabelVisible(true);

    attractionDistance = cp5.addSlider("attractionDistance", 0, 300, 100, 10, 130, 200, 20)
      .setColorActive(color(128, 0, 0))
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setLabelVisible(true);

    velocityLimit = cp5.addSlider("velocityLimit", 0, 300, 100, 10, 160, 200, 20)
      .setColorActive(color(128, 0, 0))
      .setColorBackground(color(60, 100))
      .setColorForeground(color(255, 0, 0))
      .setColorLabel(color(0, 200))
      .setColorValue(color(0, 200))
      .setLabelVisible(true);

    showParticles = cp5.addToggle("show particles")
      .setPosition(10, 190)
      .setSize(50, 20)
      .setValue(false);

    cp5.addFrameRate()
      .setInterval(10)
      .setPosition(10, 230);

    cp5.setAutoDraw(false);

    this.cubeSize = cubeSize;
  }

  void update() {
    if (grav.isInside() ||
      fric.isInside() ||
      res.isInside() ||
      meshSize.isInside() ||
      attractionDistance.isInside() ||
      velocityLimit.isInside()) {
      cam.setActive(false);
    } else {
      cam.setActive(true);
    }

    // Get slider values and pass to particle system delegate
    //println(rd.getValue(), gr.getValue(), bl.getValue());
  }

  // Gravity strength
  float getGravityModifier() {
    return grav.getValue();
  }

  // Friction strength
  float getFrictionModifier() {
    return fric.getValue();
  }

  // Number of points in field
  int getResolutionValue() {
    return (int) res.getValue();
  }

  // Radius of mesh from center of particle
  float getMeshSizeModifier() {
    return meshSize.getValue();
  }

  boolean getParticleToggleValue() {
    return showParticles.getValue() == 1.0 ? true : false;
  }

  int getAttractionDistance() {
    return (int) attractionDistance.getValue();
  }
  
  float getVelocityModifier() {
    return velocityLimit.getValue();
  }

  void show() {
    // Environment
    fill(255);
    background(132, 151, 184);
    lights();

    // Bounding box
    drawBoundingBox();

    // Draw the floor
    drawFloor();

    // HUD
    drawHUD();
  }

  private void drawBoundingBox() {
    pushMatrix();
    translate(0, 0, 250);
    // draw bounding box
    noFill();
    strokeWeight(1);
    stroke(0);
    box(500);
    popMatrix();
  }

  private void drawFloor() {
    pushMatrix();
    translate(0, 0, 0);
    fill(255);
    strokeWeight(2);
    stroke(0);
    rect(0, 0, cubeSize, cubeSize);
    popMatrix();
  }

  private void drawHUD() {
    cam.beginHUD();
    pushMatrix();
    //translate(25, height - 200);

    fill(0);
    cp5.draw();

    popMatrix();
    cam.endHUD();
  }
}
