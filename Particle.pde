class Particle {
  PVector pos, vel, acc;
  float r = 20; // radius
  int cubeSize;
  float G = 11;
  float velocityLimit = 0.6;

  Particle(PVector startingPos, int cubeSize) {
    this.pos = startingPos;
    this.vel = PVector.mult(PVector.random3D(), 0.6);
    this.acc = new PVector();

    this.cubeSize = cubeSize;
  }

  void update() {
    vel.add(acc);

    vel.limit(velocityLimit);

    // TODO: Pop bubble on collision with floor
    if (this.pos.x <= r || this.pos.x >= cubeSize - r) vel.x *= -1;
    if (this.pos.y <= r || this.pos.y >= cubeSize - r) vel.y *= -1;
    if (this.pos.z <= r || this.pos.z >= cubeSize - r) vel.z *= -1;

    pos.add(vel);

    acc.mult(0);
  }

  void show() {
    pushMatrix();
    noStroke();
    fill(255);
    translate(pos.x, pos.y, pos.z);
    sphere(r);
    popMatrix();
  }

  void attractedTo(Particle other) {
    PVector otherPos = other.getPos();
    PVector force = PVector.sub(otherPos, pos);
    float dist = force.mag();

    dist = constrain(dist, 1, 25);
    float distSq = dist * dist;

    float strength = G / distSq;
    force.setMag(strength);

    // bounce particles off ourself
    if (dist < r) force.mult(-1.2);

    applyForce(force);
  }

  void applyForce(PVector force) {
    // f = m * a => f = (1) * a => f = a;
    acc.add(force);
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
