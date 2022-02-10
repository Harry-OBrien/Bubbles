import java.util.concurrent.ExecutorService; //<>//
import java.util.concurrent.Executors;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.Future;
import java.util.concurrent.ExecutionException;
import processing.sound.*;

class ParticleSystem implements PartilePopDelegate {
  boolean showParticles = false;

  Scene scene;

  // Particles
  private ArrayList<Particle> particles;
  private float c = 0.00802; // coeff of friction
  private float gravityStrength = 0.00800001;
  private int distanceThresh = 100;
  private int particleRadius = 16;
  private int p_radius_sq;
  private ArrayList<Particle> particlesToPop;

  // Boundary
  private int cubeSize;

  // Marching cube data
  private float[][][] field;

  private int res;
  private int cols, rows, aisles;
  private float threshold;

  private BlockingQueue triangleVertices;
  private ExecutorService pool;

  private final int bubbleGunCount = 5;
  private BubbleGun[] bubbleguns;

  SoundFile popSound;

  PrintWriter output;
  long runTime = 1 * 60 * 1000;

  ParticleSystem(PApplet applet, Scene scene, int cubeSize, float threshold, int initialBubbleCount) {
    this.scene = scene;
    this.cubeSize = cubeSize;

    this.res = scene.getResolutionValue();
    this.threshold = threshold;

    this.p_radius_sq = particleRadius * particleRadius;
    this.particlesToPop = new ArrayList<Particle>();

    this.pool = Executors.newFixedThreadPool(9);
    this.triangleVertices = new LinkedBlockingQueue<ArrayList<PVector>>();

    // 3D Field
    updateFieldRes(res);

    // Particles
    this.particles = new ArrayList<Particle>();

    for (int i = 0; i < initialBubbleCount; i++) {
      addRandomBubble();
    }

    bubbleguns = new BubbleGun[bubbleGunCount];
    for (int i = 0; i < bubbleGunCount; i++) {
      PVector pos = new PVector(random(20, cubeSize - 20), random(20, cubeSize - 20), random(200, cubeSize - 20));
      PVector vel = new PVector(random(-1, 1), random(-1, 1), random(0.2, 0.8));  // any x, any 1, z facing upwards
      bubbleguns[i] = new BubbleGun(this, pos, vel, 10.0, (long) random(800, 4000));
    }

    popSound = new SoundFile(applet, "bubble_pop_short.mp3");
    
    output = createWriter("framerate_at_res_" + this.res + ".csv");
    output.println("frame,fps,particle_count");
  }

  int frame_count = 0;
  // MARK: UPDATE
  void update() {
    // Exit after a given amount of time
    if (millis() > runTime) {
      output.flush();
      output.close();
      exit();
    }
    // log data
    output.println(frame_count + "," + frameRate +"," + particles.size());
    frame_count++;
    
    for (int i = 0; i < bubbleGunCount; i++)
      bubbleguns[i].update();

    //println(particles.size());
    this.showParticles = scene.getParticleToggleValue();

    int res = scene.getResolutionValue();
    if (res != this.res) {
      updateFieldRes(res);
    }

    distanceThresh = scene.getAttractionDistance();

    // Move the particles and add any attraction and environmental forces
    updateParticles();

    // Fill in field values using particle locations <- Metaballs implementation
    calculateFieldValues();

    // Generate the mesh for the previously calculated field values
    if (!showParticles)
      createMesh();
  }

  // MARK: SHOW
  void show() {
    // Draw particles
    pushMatrix();
    translate(-(cubeSize/2), -(cubeSize/2), 0);

    // Draw the particles and bubble generators
    if (showParticles) {
      for (int i = 0; i < bubbleGunCount; i++)
        bubbleguns[i].show();

      for (Particle p : particles) p.show();

      //Draw the field
      fill(255);
      drawField();
    }

    // Now draw the bubble mesh
    else {
      drawMesh();
    }
    popMatrix();
  }

  // MARK: Field
  void updateFieldRes(int newRes) {
    this.res = newRes;

    this.cols = 1 + cubeSize / res;
    this.rows = 1 + cubeSize / res;
    this.aisles = 1 + cubeSize / res;
    this.field = new float[cols][rows][aisles];
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        for (int k = 0; k < aisles; k++) {
          // Cap off the edges
          if ( i == 0 || i == cols - 1 ||
            j == 0 || j == rows - 1 ||
            k == 0 || k == aisles - 1) {
            field[i][j][k] = max(threshold - 0.1, 0.05);
          }
        }
      }
    }
  }

  // MARK: PARTICLES
  private void updateParticles() {

    // Update particles
    for (Particle p : particles) {
      // Update slider value
      p.setVelocityLimitMultiplier(scene.getVelocityModifier() / 100);

      PVector p_pos = p.getPos();
      for (Particle other : particles) {
        //Ignore ourself
        if (p == other) continue;

        // Check if we need to merge particles
        PVector diff = PVector.sub(other.getPos(), p_pos);
        if (diff.mag() < distanceThresh) {
          p.attractedTo(other);
        }
      }

      // Apply environment variables to particle
      PVector gravity = new PVector(0, 0, -gravityStrength * scene.getGravityModifier() / 100);
      p.applyForce(gravity);

      // apply friction
      PVector friction = p.getVel();
      friction.mult(-1);
      friction.normalize();
      friction.mult(c * scene.getFrictionModifier() / 100);
      p.applyForce(friction);

      p.update();
    }

    // Remove any particles we want to pop
    for (Particle toRemove : particlesToPop) {
      assert(particles.remove(toRemove));
    }
    particlesToPop.clear();
  }

  void particleShouldPop(Particle initialPop) {
    if (particlesToPop.contains(initialPop)) return;

    // Play a 'pop' sound!
    popSound.play();

    ArrayList<Particle> particleNeighbours = new ArrayList<Particle>();
    ArrayList<Particle> unselectedParticles = (ArrayList<Particle>) particles.clone();

    particleNeighbours.add(initialPop);


    // find nearby particles
    while (!particleNeighbours.isEmpty()) {
      Particle p = particleNeighbours.get(0);
      assert(particleNeighbours.remove(p));

      particlesToPop.add(p);
      assert(unselectedParticles.remove(p));

      for (int i = 0; i < unselectedParticles.size(); i++) {
        Particle other = unselectedParticles.get(i);

        PVector diff = PVector.sub(p.getPos(), other.getPos());

        if (!particleNeighbours.contains(other) && !particlesToPop.contains(other) && diff.mag() < distanceThresh)
          particleNeighbours.add(other);
      }
    }
  }

  void addRandomBubble() {
    PVector randomPos = new PVector(random(100, 400), random(100, 400), random(100, 400));
    addBubbleAt(randomPos);
  }

  int bubbleAddedCount = 0;
  void addBubbleAt(PVector pos) {
    // Make sure within bounds
    if (pos.x > 11 && pos.x < 489 &&
      pos.y > 11 && pos.y < 489 &&
      pos.z > 11 && pos.x < 489)
    {
      Particle p = new Particle(pos, particleRadius, cubeSize, this);
      particles.add(p);
      bubbleAddedCount++;
    } else
      println("WARN: Attempted to create bubble out of environment");
  }

  void addBubbleAt(PVector pos, PVector vel) {
    // Make sure within bounds
    if (pos.x > 11 && pos.x < 489 &&
      pos.y > 11 && pos.y < 489 &&
      pos.z > 11 && pos.x < 489)
    {
      Particle p = new Particle(pos, particleRadius, cubeSize, this, vel, bubbleAddedCount == 10);
      particles.add(p);
      bubbleAddedCount++;
    } else
      println("WARN: Attempted to create bubble out of environment");
  }

  private class MetaballsValueCalculator implements Runnable {
    int col;
    ArrayList<PVector> particleLocations;

    MetaballsValueCalculator(int col, ArrayList<PVector> particleLocations) {
      this.col = col;
      this.particleLocations = particleLocations;
    }

    void run() {
      int scaledCol = col * res;
      int scaledRow = 0;
      for (int j = 0; j < rows; j++) {
        if (j == 0 || j == rows - 1) {
          // Cap off the edges - we've already set the values when creating the field
          scaledRow += res;
          continue;
        }
        int scaledAisle = 0;
        for (int k = 0; k < aisles; k++) {
          if (k == 0 || k == aisles - 1) {
            scaledAisle += res;
            continue;
          }
          // Metaballs implementation
          float sum = 0;
          PVector scaledLocation = new PVector(scaledCol, scaledRow, scaledAisle);
          for (PVector p_loc : particleLocations) {
            PVector diff = PVector.sub(scaledLocation, p_loc);
            sum += (scene.getMeshSizeModifier() / 100) * p_radius_sq / diff.magSq();
          }
          field[col][j][k] = sum;
          scaledAisle += res;
        }
        scaledRow += res;
      }
    }
  }

  private void calculateFieldValues() {
    ArrayList<Future> futures = new ArrayList<Future>();
    ArrayList<PVector> particleLocations = new ArrayList<PVector>();
    for (Particle p : particles) particleLocations.add(p.getPos());

    for (int i = 0; i < cols; i++) {
      if ( i == 0 || i == cols - 1) continue;

      MetaballsValueCalculator generator = new MetaballsValueCalculator(i, particleLocations);
      futures.add(pool.submit(generator));
    }

    for (Future f : futures) {
      try {
        f.get();
      }
      catch (ExecutionException e) {
      }
      catch (InterruptedException e) {
      }
    }
  }

  // MARK: MARCHING CUBE
  private void drawField() {
    strokeWeight(4);
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        for (int k = 0; k < aisles; k++) {
          if (field[i][j][k] < threshold) continue;

          stroke(field[i][j][k] * 255);
          point(i*res, j*res, k*res);
        }
      }
    }
  }

  private class MeshGenerator implements Runnable {
    BlockingQueue queue;
    int col;

    MeshGenerator(BlockingQueue queue, int col) {
      this.queue = queue;
      this.col = col;
    }

    public void run() {
      // Marching Cubes Algorithm
      for (int row = 0; row < rows - 1; row++) {
        for (int aisle = 0; aisle < aisles - 1; aisle++) {
          // Get the case that we should draw depending on the value of the points around us
          int cubeIndex = getCubeState(col, row, aisle);
          int[][] triangles = cases[cubeIndex];

          // For each triangle given for this case, calculate the location of the vertices
          for (int[] triangle : triangles) {
            ArrayList<PVector> vertices = new ArrayList<PVector>();
            for (int edge : triangle) {

              PVector vertex = vertexLocationForEdge(col, row, aisle, edge);

              // Add position to vertex list
              vertices.add(vertex);
            }

            // Add to a list to be drawn later!
            try {
              queue.put(vertices);
            }
            catch (InterruptedException e) {
              println("Error when adding to queue!", e);
            }
          }
        }
      }
    }
  }

  private void createMesh() {
    ArrayList<Future> futures = new ArrayList<Future>();
    // we go to rows - 1 because the final row/col/aisle doesn't have any neighbours
    for (int i = 0; i < cols - 1; i++) {
      MeshGenerator generator = new MeshGenerator(triangleVertices, i);
      futures.add(pool.submit(generator));
    }

    for (Future f : futures) {
      try {
        f.get();
      }
      catch (ExecutionException e) {
      }
      catch (InterruptedException e) {
      }
    }
  }

  private void drawMesh() {
    //fill(255, 255, 255, 200);
    fill(255);
    noStroke();
    while (!triangleVertices.isEmpty()) {
      try {
        ArrayList<PVector> vertices = (ArrayList<PVector>) triangleVertices.take();
        beginShape(TRIANGLES);
        for (PVector v : vertices) {
          vertex(v.x, v.y, v.z);
        }
        endShape();
      }
      catch(InterruptedException e) {
        println("Error when taking from queue!", e);
        break;
      }
    }
    triangleVertices.clear();
  }

  private float[] getVertices(int i, int j, int k) {
    float [] vertices = {
      field[i][j][k],
      field[i+1][j][k],
      field[i+1][j+1][k],
      field[i][j+1][k],
      field[i][j][k+1],
      field[i+1][j][k+1],
      field[i+1][j+1][k+1],
      field[i][j+1][k+1],
    };

    return vertices;
  }

  private int getCubeState(int x, int y, int z) {
    float[] vertices = getVertices(x, y, z);

    int cube_index = 0;
    for (int i = 0; i < 8; i++) {
      if (vertices[i] > threshold)
        cube_index |= 1 << i;
    }

    return cube_index;
  }

  private PVector vertexLocationForEdge(int i, int j, int k, int idx) {

    PVector edgeVertex = new PVector(i * res, j * res, k * res);
    float[] corners = getVertices(i, j, k);

    float amt = 0;
    switch(idx) {
    case 0 :
      amt = (threshold - corners[0]) / (corners[1] - corners[0]);
      edgeVertex.x += lerp(0, res, amt);
      break;

    case 1 :
      amt = (threshold - corners[1])/(corners[2] - corners[1]);
      edgeVertex.x += res;
      edgeVertex.y += lerp(0, res, amt);
      break;

    case 2 :
      amt = (threshold - corners[3])/(corners[2] - corners[3]);
      edgeVertex.x += lerp(0, res, amt);
      edgeVertex.y += res;
      break;

    case 3 :
      amt = (threshold - corners[0])/(corners[3] - corners[0]);
      edgeVertex.y += lerp(0, res, amt);
      break;

    case 4 :
      amt = (threshold - corners[4])/(corners[5] - corners[4]);
      edgeVertex.x += lerp(0, res, amt);
      edgeVertex.z += res;
      break;

    case 5 :
      amt = (threshold - corners[5])/(corners[6] - corners[5]);
      edgeVertex.x += res;
      edgeVertex.y += lerp(0, res, amt);
      edgeVertex.z += res;
      break;

    case 6 :
      amt = (threshold - corners[7])/(corners[6] - corners[7]);
      edgeVertex.x += lerp(0, res, amt);
      edgeVertex.y += res;
      edgeVertex.z += res;
      break;

    case 7 :
      amt = (threshold - corners[4])/(corners[7] - corners[4]);
      edgeVertex.y += lerp(0, res, amt);
      edgeVertex.z += res;
      break;

    case 8 :
      amt = (threshold - corners[0])/(corners[4] - corners[0]);
      edgeVertex.z += lerp(0, res, amt);
      break;

    case 9 :
      amt = (threshold - corners[1])/(corners[5] - corners[1]);
      edgeVertex.x += res;
      edgeVertex.z += lerp(0, res, amt);
      break;

    case 10 :
      amt = (threshold - corners[2])/(corners[6] - corners[2]);
      edgeVertex.x += res;
      edgeVertex.y += res;
      edgeVertex.z += lerp(0, res, amt);
      break;

    case 11 :
      amt = (threshold - corners[3])/(corners[7] - corners[3]);
      edgeVertex.y += res;
      edgeVertex.z += lerp(0, res, amt);
      break;

    default :
      println("WARN: out of bounds edge index when finding vertex");
      break;
    }

    assert(amt <= 1 && amt >= 0);
    return edgeVertex;
  }

  private int[][][] cases = {{},
    {{8, 0, 3}},
    {{1, 0, 9}},
    {{8, 1, 3}, {8, 9, 1}},
    {{10, 2, 1}},
    {{8, 0, 3}, {1, 10, 2}},
    {{9, 2, 0}, {9, 10, 2}},
    {{3, 8, 2}, {2, 8, 10}, {10, 8, 9}},
    {{3, 2, 11}},
    {{0, 2, 8}, {2, 11, 8}},
    {{1, 0, 9}, {2, 11, 3}},
    {{2, 9, 1}, {11, 9, 2}, {8, 9, 11}},
    {{3, 10, 11}, {3, 1, 10}},
    {{1, 10, 0}, {0, 10, 8}, {8, 10, 11}},
    {{0, 11, 3}, {9, 11, 0}, {10, 11, 9}},
    {{8, 9, 11}, {11, 9, 10}},
    {{7, 4, 8}},
    {{3, 7, 0}, {7, 4, 0}},
    {{7, 4, 8}, {9, 1, 0}},
    {{9, 1, 4}, {4, 1, 7}, {7, 1, 3}},
    {{7, 4, 8}, {2, 1, 10}},
    {{4, 3, 7}, {4, 0, 3}, {2, 1, 10}},
    {{2, 0, 10}, {0, 9, 10}, {7, 4, 8}},
    {{9, 10, 4}, {4, 10, 3}, {3, 10, 2}, {4, 3, 7}},
    {{4, 8, 7}, {3, 2, 11}},
    {{7, 4, 11}, {11, 4, 2}, {2, 4, 0}},
    {{1, 0, 9}, {2, 11, 3}, {8, 7, 4}},
    {{2, 11, 1}, {1, 11, 9}, {9, 11, 7}, {9, 7, 4}},
    {{10, 11, 1}, {11, 3, 1}, {4, 8, 7}},
    {{4, 0, 7}, {7, 0, 10}, {0, 1, 10}, {7, 10, 11}},
    {{7, 4, 8}, {0, 11, 3}, {9, 11, 0}, {10, 11, 9}},
    {{4, 11, 7}, {9, 11, 4}, {10, 11, 9}},
    {{9, 4, 5}},
    {{9, 4, 5}, {0, 3, 8}},
    {{0, 5, 1}, {0, 4, 5}},
    {{4, 3, 8}, {5, 3, 4}, {1, 3, 5}},
    {{5, 9, 4}, {10, 2, 1}},
    {{8, 0, 3}, {1, 10, 2}, {4, 5, 9}},
    {{10, 4, 5}, {2, 4, 10}, {0, 4, 2}},
    {{3, 10, 2}, {8, 10, 3}, {5, 10, 8}, {4, 5, 8}},
    {{9, 4, 5}, {11, 3, 2}},
    {{11, 0, 2}, {11, 8, 0}, {9, 4, 5}},
    {{5, 1, 4}, {1, 0, 4}, {11, 3, 2}},
    {{5, 1, 4}, {4, 1, 11}, {1, 2, 11}, {4, 11, 8}},
    {{3, 10, 11}, {3, 1, 10}, {5, 9, 4}},
    {{9, 4, 5}, {1, 10, 0}, {0, 10, 8}, {8, 10, 11}},
    {{5, 0, 4}, {11, 0, 5}, {11, 3, 0}, {10, 11, 5}},
    {{5, 10, 4}, {4, 10, 8}, {8, 10, 11}},
    {{9, 7, 5}, {9, 8, 7}},
    {{0, 5, 9}, {3, 5, 0}, {7, 5, 3}},
    {{8, 7, 0}, {0, 7, 1}, {1, 7, 5}},
    {{7, 5, 3}, {3, 5, 1}},
    {{7, 5, 8}, {5, 9, 8}, {2, 1, 10}},
    {{10, 2, 1}, {0, 5, 9}, {3, 5, 0}, {7, 5, 3}},
    {{8, 2, 0}, {5, 2, 8}, {10, 2, 5}, {7, 5, 8}},
    {{2, 3, 10}, {10, 3, 5}, {5, 3, 7}},
    {{9, 7, 5}, {9, 8, 7}, {11, 3, 2}},
    {{0, 2, 9}, {9, 2, 7}, {7, 2, 11}, {9, 7, 5}},
    {{3, 2, 11}, {8, 7, 0}, {0, 7, 1}, {1, 7, 5}},
    {{11, 1, 2}, {7, 1, 11}, {5, 1, 7}},
    {{3, 1, 11}, {11, 1, 10}, {8, 7, 9}, {9, 7, 5}},
    {{11, 7, 0}, {7, 5, 0}, {5, 9, 0}, {10, 11, 0}, {1, 10, 0}},
    {{0, 5, 10}, {0, 7, 5}, {0, 8, 7}, {0, 10, 11}, {0, 11, 3}},
    {{10, 11, 5}, {11, 7, 5}},
    {{5, 6, 10}},
    {{8, 0, 3}, {10, 5, 6}},
    {{0, 9, 1}, {5, 6, 10}},
    {{8, 1, 3}, {8, 9, 1}, {10, 5, 6}},
    {{1, 6, 2}, {1, 5, 6}},
    {{6, 2, 5}, {2, 1, 5}, {8, 0, 3}},
    {{5, 6, 9}, {9, 6, 0}, {0, 6, 2}},
    {{5, 8, 9}, {2, 8, 5}, {3, 8, 2}, {6, 2, 5}},
    {{3, 2, 11}, {10, 5, 6}},
    {{0, 2, 8}, {2, 11, 8}, {5, 6, 10}},
    {{3, 2, 11}, {0, 9, 1}, {10, 5, 6}},
    {{5, 6, 10}, {2, 9, 1}, {11, 9, 2}, {8, 9, 11}},
    {{11, 3, 6}, {6, 3, 5}, {5, 3, 1}},
    {{11, 8, 6}, {6, 8, 1}, {1, 8, 0}, {6, 1, 5}},
    {{5, 0, 9}, {6, 0, 5}, {3, 0, 6}, {11, 3, 6}},
    {{6, 9, 5}, {11, 9, 6}, {8, 9, 11}},
    {{7, 4, 8}, {6, 10, 5}},
    {{3, 7, 0}, {7, 4, 0}, {10, 5, 6}},
    {{7, 4, 8}, {6, 10, 5}, {9, 1, 0}},
    {{5, 6, 10}, {9, 1, 4}, {4, 1, 7}, {7, 1, 3}},
    {{1, 6, 2}, {1, 5, 6}, {7, 4, 8}},
    {{6, 1, 5}, {2, 1, 6}, {0, 7, 4}, {3, 7, 0}},
    {{4, 8, 7}, {5, 6, 9}, {9, 6, 0}, {0, 6, 2}},
    {{2, 3, 9}, {3, 7, 9}, {7, 4, 9}, {6, 2, 9}, {5, 6, 9}},
    {{2, 11, 3}, {7, 4, 8}, {10, 5, 6}},
    {{6, 10, 5}, {7, 4, 11}, {11, 4, 2}, {2, 4, 0}},
    {{1, 0, 9}, {8, 7, 4}, {3, 2, 11}, {5, 6, 10}},
    {{1, 2, 9}, {9, 2, 11}, {9, 11, 4}, {4, 11, 7}, {5, 6, 10}},
    {{7, 4, 8}, {11, 3, 6}, {6, 3, 5}, {5, 3, 1}},
    {{11, 0, 1}, {11, 4, 0}, {11, 7, 4}, {11, 1, 5}, {11, 5, 6}},
    {{6, 9, 5}, {0, 9, 6}, {11, 0, 6}, {3, 0, 11}, {4, 8, 7}},
    {{5, 6, 9}, {9, 6, 11}, {9, 11, 7}, {9, 7, 4}},
    {{4, 10, 9}, {4, 6, 10}},
    {{10, 4, 6}, {10, 9, 4}, {8, 0, 3}},
    {{1, 0, 10}, {10, 0, 6}, {6, 0, 4}},
    {{8, 1, 3}, {6, 1, 8}, {6, 10, 1}, {4, 6, 8}},
    {{9, 2, 1}, {4, 2, 9}, {6, 2, 4}},
    {{3, 8, 0}, {9, 2, 1}, {4, 2, 9}, {6, 2, 4}},
    {{0, 4, 2}, {2, 4, 6}},
    {{8, 2, 3}, {4, 2, 8}, {6, 2, 4}},
    {{4, 10, 9}, {4, 6, 10}, {2, 11, 3}},
    {{11, 8, 2}, {2, 8, 0}, {6, 10, 4}, {4, 10, 9}},
    {{2, 11, 3}, {1, 0, 10}, {10, 0, 6}, {6, 0, 4}},
    {{8, 4, 1}, {4, 6, 1}, {6, 10, 1}, {11, 8, 1}, {2, 11, 1}},
    {{3, 1, 11}, {11, 1, 4}, {1, 9, 4}, {11, 4, 6}},
    {{6, 11, 1}, {11, 8, 1}, {8, 0, 1}, {4, 6, 1}, {9, 4, 1}},
    {{3, 0, 11}, {11, 0, 6}, {6, 0, 4}},
    {{4, 11, 8}, {4, 6, 11}},
    {{6, 8, 7}, {10, 8, 6}, {9, 8, 10}},
    {{3, 7, 0}, {0, 7, 10}, {7, 6, 10}, {0, 10, 9}},
    {{1, 6, 10}, {0, 6, 1}, {7, 6, 0}, {8, 7, 0}},
    {{10, 1, 6}, {6, 1, 7}, {7, 1, 3}},
    {{9, 8, 1}, {1, 8, 6}, {6, 8, 7}, {1, 6, 2}},
    {{9, 7, 6}, {9, 3, 7}, {9, 0, 3}, {9, 6, 2}, {9, 2, 1}},
    {{7, 6, 8}, {8, 6, 0}, {0, 6, 2}},
    {{3, 6, 2}, {3, 7, 6}},
    {{3, 2, 11}, {6, 8, 7}, {10, 8, 6}, {9, 8, 10}},
    {{7, 9, 0}, {7, 10, 9}, {7, 6, 10}, {7, 0, 2}, {7, 2, 11}},
    {{0, 10, 1}, {6, 10, 0}, {8, 6, 0}, {7, 6, 8}, {2, 11, 3}},
    {{1, 6, 10}, {7, 6, 1}, {11, 7, 1}, {2, 11, 1}},
    {{1, 9, 6}, {9, 8, 6}, {8, 7, 6}, {3, 1, 6}, {11, 3, 6}},
    {{9, 0, 1}, {11, 7, 6}},
    {{0, 11, 3}, {6, 11, 0}, {7, 6, 0}, {8, 7, 0}},
    {{7, 6, 11}},
    {{11, 6, 7}},
    {{3, 8, 0}, {11, 6, 7}},
    {{1, 0, 9}, {6, 7, 11}},
    {{1, 3, 9}, {3, 8, 9}, {6, 7, 11}},
    {{10, 2, 1}, {6, 7, 11}},
    {{10, 2, 1}, {3, 8, 0}, {6, 7, 11}},
    {{9, 2, 0}, {9, 10, 2}, {11, 6, 7}},
    {{11, 6, 7}, {3, 8, 2}, {2, 8, 10}, {10, 8, 9}},
    {{2, 6, 3}, {6, 7, 3}},
    {{8, 6, 7}, {0, 6, 8}, {2, 6, 0}},
    {{7, 2, 6}, {7, 3, 2}, {1, 0, 9}},
    {{8, 9, 7}, {7, 9, 2}, {2, 9, 1}, {7, 2, 6}},
    {{6, 1, 10}, {7, 1, 6}, {3, 1, 7}},
    {{8, 0, 7}, {7, 0, 6}, {6, 0, 1}, {6, 1, 10}},
    {{7, 3, 6}, {6, 3, 9}, {3, 0, 9}, {6, 9, 10}},
    {{7, 8, 6}, {6, 8, 10}, {10, 8, 9}},
    {{8, 11, 4}, {11, 6, 4}},
    {{11, 0, 3}, {6, 0, 11}, {4, 0, 6}},
    {{6, 4, 11}, {4, 8, 11}, {1, 0, 9}},
    {{1, 3, 9}, {9, 3, 6}, {3, 11, 6}, {9, 6, 4}},
    {{8, 11, 4}, {11, 6, 4}, {1, 10, 2}},
    {{1, 10, 2}, {11, 0, 3}, {6, 0, 11}, {4, 0, 6}},
    {{2, 9, 10}, {0, 9, 2}, {4, 11, 6}, {8, 11, 4}},
    {{3, 4, 9}, {3, 6, 4}, {3, 11, 6}, {3, 9, 10}, {3, 10, 2}},
    {{3, 2, 8}, {8, 2, 4}, {4, 2, 6}},
    {{2, 4, 0}, {6, 4, 2}},
    {{0, 9, 1}, {3, 2, 8}, {8, 2, 4}, {4, 2, 6}},
    {{1, 2, 9}, {9, 2, 4}, {4, 2, 6}},
    {{10, 3, 1}, {4, 3, 10}, {4, 8, 3}, {6, 4, 10}},
    {{10, 0, 1}, {6, 0, 10}, {4, 0, 6}},
    {{3, 10, 6}, {3, 9, 10}, {3, 0, 9}, {3, 6, 4}, {3, 4, 8}},
    {{9, 10, 4}, {10, 6, 4}},
    {{9, 4, 5}, {7, 11, 6}},
    {{9, 4, 5}, {7, 11, 6}, {0, 3, 8}},
    {{0, 5, 1}, {0, 4, 5}, {6, 7, 11}},
    {{11, 6, 7}, {4, 3, 8}, {5, 3, 4}, {1, 3, 5}},
    {{1, 10, 2}, {9, 4, 5}, {6, 7, 11}},
    {{8, 0, 3}, {4, 5, 9}, {10, 2, 1}, {11, 6, 7}},
    {{7, 11, 6}, {10, 4, 5}, {2, 4, 10}, {0, 4, 2}},
    {{8, 2, 3}, {10, 2, 8}, {4, 10, 8}, {5, 10, 4}, {11, 6, 7}},
    {{2, 6, 3}, {6, 7, 3}, {9, 4, 5}},
    {{5, 9, 4}, {8, 6, 7}, {0, 6, 8}, {2, 6, 0}},
    {{7, 3, 6}, {6, 3, 2}, {4, 5, 0}, {0, 5, 1}},
    {{8, 1, 2}, {8, 5, 1}, {8, 4, 5}, {8, 2, 6}, {8, 6, 7}},
    {{9, 4, 5}, {6, 1, 10}, {7, 1, 6}, {3, 1, 7}},
    {{7, 8, 6}, {6, 8, 0}, {6, 0, 10}, {10, 0, 1}, {5, 9, 4}},
    {{3, 0, 10}, {0, 4, 10}, {4, 5, 10}, {7, 3, 10}, {6, 7, 10}},
    {{8, 6, 7}, {10, 6, 8}, {5, 10, 8}, {4, 5, 8}},
    {{5, 9, 6}, {6, 9, 11}, {11, 9, 8}},
    {{11, 6, 3}, {3, 6, 0}, {0, 6, 5}, {0, 5, 9}},
    {{8, 11, 0}, {0, 11, 5}, {5, 11, 6}, {0, 5, 1}},
    {{6, 3, 11}, {5, 3, 6}, {1, 3, 5}},
    {{10, 2, 1}, {5, 9, 6}, {6, 9, 11}, {11, 9, 8}},
    {{3, 11, 0}, {0, 11, 6}, {0, 6, 9}, {9, 6, 5}, {1, 10, 2}},
    {{0, 8, 5}, {8, 11, 5}, {11, 6, 5}, {2, 0, 5}, {10, 2, 5}},
    {{11, 6, 3}, {3, 6, 5}, {3, 5, 10}, {3, 10, 2}},
    {{3, 9, 8}, {6, 9, 3}, {5, 9, 6}, {2, 6, 3}},
    {{9, 6, 5}, {0, 6, 9}, {2, 6, 0}},
    {{6, 5, 8}, {5, 1, 8}, {1, 0, 8}, {2, 6, 8}, {3, 2, 8}},
    {{2, 6, 1}, {6, 5, 1}},
    {{6, 8, 3}, {6, 9, 8}, {6, 5, 9}, {6, 3, 1}, {6, 1, 10}},
    {{1, 10, 0}, {0, 10, 6}, {0, 6, 5}, {0, 5, 9}},
    {{3, 0, 8}, {6, 5, 10}},
    {{10, 6, 5}},
    {{5, 11, 10}, {5, 7, 11}},
    {{5, 11, 10}, {5, 7, 11}, {3, 8, 0}},
    {{11, 10, 7}, {10, 5, 7}, {0, 9, 1}},
    {{5, 7, 10}, {10, 7, 11}, {9, 1, 8}, {8, 1, 3}},
    {{2, 1, 11}, {11, 1, 7}, {7, 1, 5}},
    {{3, 8, 0}, {2, 1, 11}, {11, 1, 7}, {7, 1, 5}},
    {{2, 0, 11}, {11, 0, 5}, {5, 0, 9}, {11, 5, 7}},
    {{2, 9, 5}, {2, 8, 9}, {2, 3, 8}, {2, 5, 7}, {2, 7, 11}},
    {{10, 3, 2}, {5, 3, 10}, {7, 3, 5}},
    {{10, 0, 2}, {7, 0, 10}, {8, 0, 7}, {5, 7, 10}},
    {{0, 9, 1}, {10, 3, 2}, {5, 3, 10}, {7, 3, 5}},
    {{7, 8, 2}, {8, 9, 2}, {9, 1, 2}, {5, 7, 2}, {10, 5, 2}},
    {{3, 1, 7}, {7, 1, 5}},
    {{0, 7, 8}, {1, 7, 0}, {5, 7, 1}},
    {{9, 5, 0}, {0, 5, 3}, {3, 5, 7}},
    {{5, 7, 9}, {7, 8, 9}},
    {{4, 10, 5}, {8, 10, 4}, {11, 10, 8}},
    {{3, 4, 0}, {10, 4, 3}, {10, 5, 4}, {11, 10, 3}},
    {{1, 0, 9}, {4, 10, 5}, {8, 10, 4}, {11, 10, 8}},
    {{4, 3, 11}, {4, 1, 3}, {4, 9, 1}, {4, 11, 10}, {4, 10, 5}},
    {{1, 5, 2}, {2, 5, 8}, {5, 4, 8}, {2, 8, 11}},
    {{5, 4, 11}, {4, 0, 11}, {0, 3, 11}, {1, 5, 11}, {2, 1, 11}},
    {{5, 11, 2}, {5, 8, 11}, {5, 4, 8}, {5, 2, 0}, {5, 0, 9}},
    {{5, 4, 9}, {2, 3, 11}},
    {{3, 4, 8}, {2, 4, 3}, {5, 4, 2}, {10, 5, 2}},
    {{5, 4, 10}, {10, 4, 2}, {2, 4, 0}},
    {{2, 8, 3}, {4, 8, 2}, {10, 4, 2}, {5, 4, 10}, {0, 9, 1}},
    {{4, 10, 5}, {2, 10, 4}, {1, 2, 4}, {9, 1, 4}},
    {{8, 3, 4}, {4, 3, 5}, {5, 3, 1}},
    {{1, 5, 0}, {5, 4, 0}},
    {{5, 0, 9}, {3, 0, 5}, {8, 3, 5}, {4, 8, 5}},
    {{5, 4, 9}},
    {{7, 11, 4}, {4, 11, 9}, {9, 11, 10}},
    {{8, 0, 3}, {7, 11, 4}, {4, 11, 9}, {9, 11, 10}},
    {{0, 4, 1}, {1, 4, 11}, {4, 7, 11}, {1, 11, 10}},
    {{10, 1, 4}, {1, 3, 4}, {3, 8, 4}, {11, 10, 4}, {7, 11, 4}},
    {{9, 4, 1}, {1, 4, 2}, {2, 4, 7}, {2, 7, 11}},
    {{1, 9, 2}, {2, 9, 4}, {2, 4, 11}, {11, 4, 7}, {3, 8, 0}},
    {{11, 4, 7}, {2, 4, 11}, {0, 4, 2}},
    {{7, 11, 4}, {4, 11, 2}, {4, 2, 3}, {4, 3, 8}},
    {{10, 9, 2}, {2, 9, 7}, {7, 9, 4}, {2, 7, 3}},
    {{2, 10, 7}, {10, 9, 7}, {9, 4, 7}, {0, 2, 7}, {8, 0, 7}},
    {{10, 4, 7}, {10, 0, 4}, {10, 1, 0}, {10, 7, 3}, {10, 3, 2}},
    {{8, 4, 7}, {10, 1, 2}},
    {{4, 1, 9}, {7, 1, 4}, {3, 1, 7}},
    {{8, 0, 7}, {7, 0, 1}, {7, 1, 9}, {7, 9, 4}},
    {{0, 7, 3}, {0, 4, 7}},
    {{8, 4, 7}},
    {{9, 8, 10}, {10, 8, 11}},
    {{3, 11, 0}, {0, 11, 9}, {9, 11, 10}},
    {{0, 10, 1}, {8, 10, 0}, {11, 10, 8}},
    {{11, 10, 3}, {10, 1, 3}},
    {{1, 9, 2}, {2, 9, 11}, {11, 9, 8}},
    {{9, 2, 1}, {11, 2, 9}, {3, 11, 9}, {0, 3, 9}},
    {{8, 2, 0}, {8, 11, 2}},
    {{11, 2, 3}},
    {{2, 8, 3}, {10, 8, 2}, {9, 8, 10}},
    {{0, 2, 9}, {2, 10, 9}},
    {{3, 2, 8}, {8, 2, 10}, {8, 10, 1}, {8, 1, 0}},
    {{1, 2, 10}},
    {{3, 1, 8}, {1, 9, 8}},
    {{9, 0, 1}},
    {{3, 0, 8}},
    {}};
}
