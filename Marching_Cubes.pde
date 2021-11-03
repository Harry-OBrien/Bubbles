import peasy.*; //<>//

PeasyCam cam;

float[][][] field;

// TODO: Control resolution by slider
private int res = 8;
private int cols, rows, aisles;
private int cubeSize = 500;
private float threshold = 0.4;

void setup() {
  fullScreen(P3D);
  pixelDensity(2);
  noCursor();
  frameRate(60);
  cam = new PeasyCam(this, 500);
  cam.setMaximumDistance(1200);
  cam.setMinimumDistance(50);
  cam.setWheelScale(0.3);

  cols = 1 + cubeSize / res;
  rows = 1 + cubeSize / res;
  aisles = 1 + cubeSize / res;
  field = new float[cols][rows][aisles];

  OpenSimplexNoise noise = new OpenSimplexNoise();

  float increment = 0.1;
  float xOff = 0;

  for (int i = 0; i < cols; i++) {
    xOff += increment;
    float yOff = 0;

    for (int j = 0; j < rows; j++) {
      yOff += increment;
      float zOff = 0;

      for (int k = 0; k < aisles; k++) {
        PVector pos = new PVector(i, j, k);
        field[i][j][k] = (float)(noise.eval(xOff, yOff, zOff));
        zOff += increment;
      }
    }
  }

  rectMode(CENTER);
}

void draw() {
  translate(0, 0, -200);
  background(132, 151, 184);
  lights();

  // Draw the floor
  drawFloor();

  pushMatrix();
  strokeWeight(4);
  translate(-(cubeSize/2), -(cubeSize/2), 0);

  //Draw the field
  //drawField();

  strokeWeight(0);
  
  // we go to rows - 1 because the final row/col/aisle doesn't have any neighbours
  for (int i = 0; i < cols - 1; i++) {
    for (int j = 0; j < rows - 1; j++) {
      for (int k = 0; k < aisles - 1; k++) {

        int cubeIndex = getState(i, j, k);

        int[][] triangles = cases[cubeIndex];

        for (int[] triangle : triangles) {
          ArrayList<PVector> vertices = new ArrayList<PVector>();
          for (int edge : triangle) {

            PVector vertex = vertexLocationForEdge(i, j, k, edge);

            // Add position to vertex list
            vertices.add(vertex);
          }

          // Draw triangle
          beginShape(TRIANGLES);
          for (PVector v : vertices) {
            vertex(v.x, v.y, v.z);
          }
          endShape();
        }
      }
    }
  }
  popMatrix();
}

void drawFloor() {
  pushMatrix();
  translate(0, 0, 0);
  strokeWeight(2);
  stroke(0);
  rect(0, 0, cubeSize, cubeSize);
  popMatrix();
}

void drawField() {
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

float[] getVertices(int i, int j, int k) {
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

int getState(int x, int y, int z) {
  float[] vertices = getVertices(x, y, z);

  int cube_index = 0;
  for (int i = 0; i < 8; i++) {
    if (vertices[i] > threshold)
      cube_index |= 1 << i;
  }

  return cube_index;
}

PVector vertexLocationForEdge(int i, int j, int k, int idx) {

  PVector edgeVertex = new PVector(i * res, j * res, k * res);
  float[] corners = getVertices(i, j, k);

  float amt = 0;
  switch(idx) {
  case 0:
    amt = (threshold - corners[0]) / (corners[1] - corners[0]);
    edgeVertex.x += lerp(0, res, amt);
    break;

  case 1:
    amt = (threshold - corners[1])/(corners[2] - corners[1]);
    edgeVertex.x += res;
    edgeVertex.y += lerp(0, res, amt);
    break;

  case 2:
    amt = (threshold - corners[3])/(corners[2] - corners[3]);
    edgeVertex.x += lerp(0, res, amt);
    edgeVertex.y += res;
    break;

  case 3:
    amt = (threshold - corners[0])/(corners[3] - corners[0]);
    edgeVertex.y += lerp(0, res, amt);
    break;

  case 4:
    amt = (threshold - corners[4])/(corners[5] - corners[4]);
    edgeVertex.x += lerp(0, res, amt);
    edgeVertex.z += res;
    break;

  case 5:
    amt = (threshold - corners[5])/(corners[6] - corners[5]);
    edgeVertex.x += res;
    edgeVertex.y += lerp(0, res, amt);
    edgeVertex.z += res;
    break;

  case 6:
    amt = (threshold - corners[7])/(corners[6] - corners[7]);
    edgeVertex.x += lerp(0, res, amt);
    edgeVertex.y += res;
    edgeVertex.z += res;
    break;

  case 7:
    amt = (threshold - corners[4])/(corners[7] - corners[4]);
    edgeVertex.y += lerp(0, res, amt);
    edgeVertex.z += res;
    break;

  case 8:
    amt = (threshold - corners[0])/(corners[4] - corners[0]);
    edgeVertex.z += lerp(0, res, amt);
    break;

  case 9:
    amt = (threshold - corners[1])/(corners[5] - corners[1]);
    edgeVertex.x += res;
    edgeVertex.z += lerp(0, res, amt);
    break;

  case 10:
    amt = (threshold - corners[2])/(corners[6] - corners[2]);
    edgeVertex.x += res;
    edgeVertex.y += res;
    edgeVertex.z += lerp(0, res, amt);
    break;

  case 11:
    amt = (threshold - corners[3])/(corners[7] - corners[3]);
    edgeVertex.y += res;
    edgeVertex.z += lerp(0, res, amt);
    break;

  default:
    println("WARN: out of bounds edge index when finding vertex");
    break;
  }

  assert(amt <= 1 && amt > 0);
  return edgeVertex;
}
