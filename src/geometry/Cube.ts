import {vec3, vec4} from 'gl-matrix';
import Drawable from '../rendering/gl/Drawable';
import {gl} from '../globals';

// origin + u * edgeU + v * edgeV walks a face; edgeU x edgeV points outward.
const FACES: Array<{origin: number[], edgeU: number[], edgeV: number[], normal: number[]}> = [
  { origin: [-1, -1,  1], edgeU: [ 2,  0,  0], edgeV: [0,  2,  0], normal: [ 0,  0,  1] }, // +Z
  { origin: [ 1, -1, -1], edgeU: [-2,  0,  0], edgeV: [0,  2,  0], normal: [ 0,  0, -1] }, // -Z
  { origin: [ 1, -1,  1], edgeU: [ 0,  0, -2], edgeV: [0,  2,  0], normal: [ 1,  0,  0] }, // +X
  { origin: [-1, -1, -1], edgeU: [ 0,  0,  2], edgeV: [0,  2,  0], normal: [-1,  0,  0] }, // -X
  { origin: [-1,  1,  1], edgeU: [ 2,  0,  0], edgeV: [0,  0, -2], normal: [ 0,  1,  0] }, // +Y
  { origin: [-1, -1, -1], edgeU: [ 2,  0,  0], edgeV: [0,  0,  2], normal: [ 0, -1,  0] }, // -Y
];

class Cube extends Drawable {
  indices: Uint32Array;
  positions: Float32Array;
  normals: Float32Array;
  center: vec4;

  // Faces are subdivided into a grid because the vertex shader displaces along
  // normals -- with only the 8 corners there'd be nothing inside a face to move.
  constructor(center: vec3, public radius: number = 1, public subdivisions: number = 32) {
    super(); // Call the constructor of the super class. This is required.
    this.center = vec4.fromValues(center[0], center[1], center[2], 1);
  }

  create() {
    const n = Math.max(1, this.subdivisions);
    const vertsPerSide = n + 1;
    const vertsPerFace = vertsPerSide * vertsPerSide;

    // No vertices shared between faces, so each one keeps a single flat normal.
    this.positions = new Float32Array(FACES.length * vertsPerFace * 4);
    this.normals = new Float32Array(FACES.length * vertsPerFace * 4);
    this.indices = new Uint32Array(FACES.length * n * n * 6);

    let idx = 0;

    for (let f = 0; f < FACES.length; ++f) {
      const face = FACES[f];
      const firstVert = f * vertsPerFace;

      for (let j = 0; j < vertsPerSide; ++j) {
        for (let i = 0; i < vertsPerSide; ++i) {
          const u = i / n;
          const v = j / n;
          const offset = (firstVert + j * vertsPerSide + i) * 4;

          for (let axis = 0; axis < 3; ++axis) {
            const local = face.origin[axis] + u * face.edgeU[axis] + v * face.edgeV[axis];
            this.positions[offset + axis] = this.center[axis] + local * this.radius;
            this.normals[offset + axis] = face.normal[axis];
          }
          this.positions[offset + 3] = 1;
          this.normals[offset + 3] = 0;
        }
      }

      for (let j = 0; j < n; ++j) {
        for (let i = 0; i < n; ++i) {
          const a = firstVert + j * vertsPerSide + i;
          const b = a + 1;
          const c = b + vertsPerSide;
          const d = a + vertsPerSide;
          this.indices[idx++] = a;
          this.indices[idx++] = b;
          this.indices[idx++] = c;
          this.indices[idx++] = a;
          this.indices[idx++] = c;
          this.indices[idx++] = d;
        }
      }
    }

    this.generateIdx();
    this.generatePos();
    this.generateNor();

    this.count = this.indices.length;
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.bufIdx);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, this.indices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bufNor);
    gl.bufferData(gl.ARRAY_BUFFER, this.normals, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bufPos);
    gl.bufferData(gl.ARRAY_BUFFER, this.positions, gl.STATIC_DRAW);

    console.log(`Created cube with ${this.positions.length / 4} vertices`);
  }
};

export default Cube;
