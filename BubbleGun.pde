class BubbleGun {
  ParticleSystem parent;
  PVector initialPos, initialVelocity;
  long repeatTime, timeNextBubble = 0;

  BubbleGun(ParticleSystem parent, PVector pos, PVector bubbleDirection, float bubbleSpeed, long reptition_millis) {
    this.parent = parent;

    this.initialPos = pos;
    this.initialVelocity = PVector.mult(bubbleDirection.normalize(), bubbleSpeed);

    this.repeatTime = reptition_millis;
  }

  void update() {
    if (millis() - timeNextBubble > repeatTime) {
      timeNextBubble = millis() + repeatTime;
      parent.addBubbleAt(initialPos.copy(), initialVelocity.copy());
    }
  }
  
  void show() {
    pushMatrix();
    translate(initialPos.x, initialPos.y, initialPos.z);
    strokeWeight(2);
    stroke(00, 255, 0);
    line(0, 0, 0, initialVelocity.x * 10, initialVelocity.y * 10, initialVelocity.z * 10);
    fill(255, 0, 0);
    noStroke();
    sphere(10);
    popMatrix();
  }
}
