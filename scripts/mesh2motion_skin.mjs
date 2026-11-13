// Reproducible adapter to the installed, unmodified Mesh2Motion skinning engine.
// node --import <engine>/node_modules/tsx/dist/loader.mjs this-file engine input output
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const [engine, inputPath, outputPath] = process.argv.slice(2);
const fromEngine = p => pathToFileURL(path.resolve(engine, p)).href;
const { Bone, Group, BufferGeometry, BufferAttribute, Vector3 } = await import(fromEngine('node_modules/three/build/three.module.js'));
const { default: SkinningAlgorithm } = await import(fromEngine('src/lib/solvers/SkinningAlgorithm.ts'));
const { SkeletonType } = await import(fromEngine('src/lib/enums/SkeletonType.ts'));
const input = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
const armature = new Group(), byName = new Map();
for (const spec of input.bones) {
  const bone = new Bone();
  bone.name = spec.solver_name;
  bone.userData.semantic_name = spec.name;
  const parent = spec.parent ? byName.get(spec.parent) : armature;
  parent.add(bone);
  bone.position.copy(parent.worldToLocal(new Vector3(...spec.world_position)));
  bone.updateWorldMatrix(true, true);
  byName.set(spec.name, bone);
}
armature.updateMatrixWorld(true);
const ordered = [];
armature.traverse(object => { if (object.isBone) ordered.push(object); });
const geometry = new BufferGeometry();
geometry.setAttribute('position', new BufferAttribute(new Float32Array(input.positions), 3));
geometry.setIndex(new BufferAttribute(new Uint32Array(input.triangles), 1));
const skeletonType = input.skeleton_type ?? SkeletonType.Human;
if (!Object.values(SkeletonType).includes(skeletonType)) throw Error('Unknown skeleton type');
const solver = new SkinningAlgorithm(armature.children[0], skeletonType);
solver.set_geometry(geometry);
solver.set_head_weight_correction_enabled(input.head_correction ?? true);
solver.set_preview_plane_height(input.head_plane ?? 1.4);
const [indices, weights] = solver.calculate_indexes_and_weights();
const names = ordered.map(b => b.userData.semantic_name);
const count = input.positions.length / 3;
if (indices.length !== count * 4 || weights.length !== count * 4) throw Error('Invalid output size');
for (let vertex = 0; vertex < count; vertex++) {
  let sum = 0;
  for (let slot = 0; slot < 4; slot++) {
    const index = vertex * 4 + slot;
    if (!Number.isFinite(weights[index]) || weights[index] < 0 || !names[indices[index]]) throw Error('Invalid skin');
    sum += weights[index];
  }
  if (Math.abs(sum - 1) > 1e-5) throw Error('Unnormalized skin');
}
fs.writeFileSync(outputPath, JSON.stringify({
  provider: 'Mesh2Motion', engine_commit: 'e66f13ccf00ba0afc07e82d876af016e40792422',
  template: input.template ?? 'fitted semantic biped with orientation leaves',
  skeleton_type: skeletonType,
  core_solver_modified: false, vertices: count, bone_names: names, indices, weights
}));
console.log('MESH2MOTION_SKIN_DONE', input.id, count);
