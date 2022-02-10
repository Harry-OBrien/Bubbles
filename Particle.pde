class Particle {
  PVector pos, vel, acc;
  float r; // radius
  int cubeSize;
  float G = 8;

  float velocityLimit = 1.6;
  float velocityLimitMultiplier = 1;

  PartilePopDelegate delegate;

  Boolean attracted = false;

  Particle(PVector startingPos, float r, int cubeSize, PartilePopDelegate delegate, PVector startingVel, Boolean chosen) {
    this.pos = startingPos;
    this.vel = startingVel;
    this.acc = new PVector();
    this.r = r;

    this.delegate = delegate;
    this.cubeSize = cubeSize;
  }

  Particle(PVector startingPos, float r, int cubeSize, PartilePopDelegate delegate) {
    this(startingPos, r, cubeSize, delegate, new PVector(), false);
  }

  void update() {
    vel.add(acc);
    vel.limit(velocityLimit * velocityLimitMultiplier);

    // Bound of walls, pop when hit floor
    if (this.pos.x <= r || this.pos.x >= cubeSize - r) vel.x *= -1;
    if (this.pos.y <= r || this.pos.y >= cubeSize - r) vel.y *= -1;
    if (this.pos.z >= cubeSize - r) vel.z *= -1;
    if (this.pos.z <= r) {
      delegate.particleShouldPop(this);
      return;
    }

    pos.add(vel);

    // We only remove some of the acceleration to immitate inertia
    acc.mult(0.8);

    attracted = false;
  }

  void show() {
    pushMatrix();
    noStroke();
    fill(255);
    translate(pos.x, pos.y, pos.z);
    sphere(r);
    popMatrix();
  }

  void setVelocityLimitMultiplier(float multiplier) {
    multiplier = constrain(multiplier, 0, 1);
    velocityLimitMultiplier = multiplier;
  }

  void attractedTo(Particle other) {
    attracted = true;

    PVector target = other.getPos();
    PVector force = PVector.sub(target, pos);
    float dist = force.mag();
    dist = constrain(dist, 5, 25);

    float distSq = dist * dist;

    float strength = G / distSq;
    force.setMag(strength);

    // bounce particles off ourself
    if (dist < r) force.mult(-0.1);

    applyForce(force);
  }

  void applyForce(PVector force) {
    // f/m = a
    acc.add(PVector.div(force, r / 10));
  }

  PVector getPos() {
    return pos.copy();
  }
  PVector getVel() {
    return vel.copy();
  }
  float getRadius() {
    return r;
  }
}
