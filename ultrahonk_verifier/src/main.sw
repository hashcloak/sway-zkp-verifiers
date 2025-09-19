contract;

use std::hash::Hash;
use std::hash::keccak256;
use std::array_conversions::u256::*;
use std::bytes_conversions::u256::*;
use std::bytes::Bytes;
#[error_type]
enum VerifierErrors {
    #[error(m = "Sumcheck failed.")]
    SumcheckFailed: (),
    #[error(m = "Shplemini failed.")]
    ShpleminiFailed: (),
    #[error(m = "Public inputs length wrong.")]
    PublicInputsLengthWrong: (),
}

const ZERO: u256 = 0;

const N: u256 = 4096;
const LOG_N: u256 = 12;
const NUMBER_OF_PUBLIC_INPUTS: u64 = 17;

// ORIGINAL FROM SOLIDITY 21888242871839275222246405745257275088548364400416034343698204186575808495617
// Prime field order, F_r (used for all modular arithmetic)
const MODULUS: u256 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001u256;

// EC group order, F_q
const Q: u256 = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47u256;

// Minus one in the field
const MINUS_ONE: u256 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000u256; // = MODULUS - 1

const CONST_PROOF_SIZE_LOG_N: u64 = 28;
const CONST_PROOF_SIZE_LOG_N_MINUS_1: u64 = 27;
const NUMBER_OF_SUBRELATIONS: u64 = 26;
const BATCHED_RELATION_PARTIAL_LENGTH: u64 = 8;
const NUMBER_OF_ENTITIES: u64 = 40;
const NUMBER_UNSHIFTED: u64 = 35;
// Unused, but keeping for consistency with Solidity
const NUMBER_TO_BE_SHIFTED: u64 = 5;
const PAIRING_POINTS_SIZE: u64 = 16;
const NUMBER_OF_ALPHAS: u64 = 25;

// Functions hardcoded mod MODULUS
impl u256 {
  fn addmod(self, other: u256) -> u256 {
      let mut res: u256 = 0;
      asm (rA: res, rB: self, rC: other, rD: MODULUS) {
      wqam rA rB rC rD;
      };
      res
  }

  fn mulmod(self, other: u256) -> u256 {
      let mut res: u256 = 0;
      asm (rA: res, rB: self, rC: other, rD: MODULUS) {
      wqmm rA rB rC rD;
      }
      res
  }

  fn submod(self, other: u256) -> u256 {
      let mut res: u256 = MODULUS - other;
      asm (rA: res, rB: self, rD: MODULUS) {
      wqam rA rB rA rD;
      }
      res
  }
}

// Computes the inverse using the extended euclidean algorithm
fn inverse(a: u256) -> u256 {
    let mut t = 0;
    let mut newt = 1;
    let mut r = MODULUS;
    let mut newr = a;
    let mut quotient = 0;
    let mut aux = 0;
    while newr != 0 {
      quotient = r / newr;
      // aux = t - quotient*newt
      let mut qt = 0;
      asm (rA: qt, rB: quotient, rC: newt, rD: MODULUS){
        wqmm rA rB rC rD;
      }
      qt = MODULUS - qt;
      asm (rA: aux, rB: t, rC: qt, rD: MODULUS){
        wqam rA rB rC rD;
      }
      t = newt;
      newt = aux;
      // aux = r - quotient*newr
      let mut qr = 0;
      asm (rA: qr, rB: quotient, rC: newr, rD: MODULUS){
        wqmm rA rB rC rD;
      }
      qr = MODULUS - qr;
      asm (rA: aux, rB: r, rC: qr, rD: MODULUS){
        wqam rA rB rC rD;
      }
      r = newr;
      newr = aux;
    };
    t
}

// G1
pub struct G1Point {
    pub x: u256,
    pub y: u256,
}

// G1ProofPoint
pub struct G1ProofPoint {
    pub x: [u256;2],
    pub y: [u256;2],
}

// [1]_2
const G2x1: u256 = 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6edu256;
const G2x2: u256 = 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2u256;
const G2y1: u256 = 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daau256;
const G2y2: u256 = 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975bu256;

// Values from VK (dynamic)
const X2x1: u256 = 0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0u256;
const X2x2: u256 = 0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1u256;
const X2y1: u256 = 0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55u256;
const X2y2: u256 = 0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4u256;


pub fn convert_proof_point(input: G1ProofPoint) -> G1Point {
    G1Point {
        x: input.x[0] | (input.x[1] << 136),
        y: input.y[0] | (input.y[1] << 136),
    }
}

impl G1Point {

    pub fn point_add(self, other: G1Point) -> Self {
        let mut input: [u256; 4] = [0; 4];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = self.x;
        input[1] = self.y;
        input[2] = other.x;
        input[3] = other.y;

        // ecc addition opcode
        asm(rA: output, rB: 0, rC: 0, rD: input) {
            ecop rA rB rC rD;
        }
        
        G1Point{
            x: output[0],
            y: output[1],
        }
    }

    pub fn u256_mul(self, s: u256) -> Self {
        let mut input: [u256; 3] = [0; 3];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = self.x;
        input[1] = self.y;
        input[2] = s;

        // ecc multiplication opcode
        asm(rA: output, rB: 0, rC: 1, rD: input) {
            ecop rA rB rC rD;
        }

        G1Point{
            x: output[0],
            y: output[1],
        }
    }
}

// 70 = N = NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N + 2
pub fn batch_mul(points: [G1Point; 70], scalars: [u256; 70]) -> G1Point {
    let mut acc = points[0].u256_mul(scalars[0]);
    let mut i = 1;
    while i < 70 {
        let tmp = points[i].u256_mul(scalars[i]);
        acc = acc.point_add(tmp);
        i += 1;
    }
    acc
}

pub struct VerificationKey {
    // Misc Params
    pub circuit_size: u256,
    pub log_circuit_size: u256,
    pub public_inputs_size: u256,

    // Selectors
    pub qm: G1Point,
    pub qc: G1Point,
    pub ql: G1Point,
    pub qr: G1Point,
    pub qo: G1Point,
    pub q4: G1Point,
    pub q_lookup: G1Point,
    pub q_arith: G1Point,
    pub q_delta_range: G1Point,
    pub q_aux: G1Point,
    pub q_elliptic: G1Point,
    pub q_poseidon2_external: G1Point,
    pub q_poseidon2_internal: G1Point,

    // Copy constraints
    pub s1: G1Point,
    pub s2: G1Point,
    pub s3: G1Point,
    pub s4: G1Point,

    // Copy identity
    pub id1: G1Point,
    pub id2: G1Point,
    pub id3: G1Point,
    pub id4: G1Point,

    // Precomputed lookup table
    pub t1: G1Point,
    pub t2: G1Point,
    pub t3: G1Point,
    pub t4: G1Point,

    // Fixed first and last Lagrange selectors
    pub lagrange_first: G1Point,
    pub lagrange_last: G1Point,
}

pub struct RelationParameters {
    // Fiat-Shamir challenges
    pub eta: u256,
    pub eta_two: u256,
    pub eta_three: u256,
    pub beta: u256,
    pub gamma: u256,
    // derived
    pub public_inputs_delta: u256,
}

pub struct Proof {
    // Pairing point object (values in Fr)
    // PAIRING_POINTS_SIZE
    pub pairing_point_object: [u256; 16],

    // Free wires
    pub w1: G1ProofPoint,
    pub w2: G1ProofPoint,
    pub w3: G1ProofPoint,
    pub w4: G1ProofPoint,

    // Lookup helpers - Permutations
    pub z_perm: G1ProofPoint,

    // Lookup helpers - Lookup-specific
    pub lookup_read_counts: G1ProofPoint,
    pub lookup_read_tags: G1ProofPoint,
    pub lookup_inverses: G1ProofPoint,

    // Sumcheck
    // pub sumcheck_univariates: [[u256; BATCHED_RELATION_PARTIAL_LENGTH]; CONST_PROOF_SIZE_LOG_N],
    pub sumcheck_univariates: [[u256; 8]; 28],
    // NUMBER_OF_ENTITIES
    pub sumcheck_evaluations: [u256; 40],

    // Shplemini (Gemini commitments + Shplonk opening proof)
    // CONST_PROOF_SIZE_LOG_N_MINUS_1
    pub gemini_fold_comms: [G1ProofPoint; 27],
    // CONST_PROOF_SIZE_LOG_N
    pub gemini_a_evaluations: [u256; 28],
    pub shplonk_q: G1ProofPoint,
    pub kzg_quotient: G1ProofPoint,
}

// Replacement for enum WIRES in Solidity
// (this is used for indexing into sumcheck_evaluations of the Proof struct)
pub const WIRE_Q_M: u64                  = 0;
pub const WIRE_Q_C: u64                  = 1;
pub const WIRE_Q_L: u64                  = 2;
pub const WIRE_Q_R: u64                  = 3;
pub const WIRE_Q_O: u64                  = 4;
pub const WIRE_Q_4: u64                  = 5;
pub const WIRE_Q_LOOKUP: u64             = 6;
pub const WIRE_Q_ARITH: u64              = 7;
pub const WIRE_Q_RANGE: u64              = 8;
pub const WIRE_Q_ELLIPTIC: u64           = 9;
pub const WIRE_Q_AUX: u64                = 10;
pub const WIRE_Q_POSEIDON2_EXTERNAL: u64 = 11;
pub const WIRE_Q_POSEIDON2_INTERNAL: u64 = 12;
pub const WIRE_SIGMA_1: u64              = 13;
pub const WIRE_SIGMA_2: u64              = 14;
pub const WIRE_SIGMA_3: u64              = 15;
pub const WIRE_SIGMA_4: u64              = 16;
pub const WIRE_ID_1: u64                 = 17;
pub const WIRE_ID_2: u64                 = 18;
pub const WIRE_ID_3: u64                 = 19;
pub const WIRE_ID_4: u64                 = 20;
pub const WIRE_TABLE_1: u64              = 21;
pub const WIRE_TABLE_2: u64              = 22;
pub const WIRE_TABLE_3: u64              = 23;
pub const WIRE_TABLE_4: u64              = 24;
pub const WIRE_LAGRANGE_FIRST: u64       = 25;
pub const WIRE_LAGRANGE_LAST: u64        = 26;
pub const WIRE_W_L: u64                  = 27;
pub const WIRE_W_R: u64                  = 28;
pub const WIRE_W_O: u64                  = 29;
pub const WIRE_W_4: u64                  = 30;
pub const WIRE_Z_PERM: u64               = 31;
pub const WIRE_LOOKUP_INVERSES: u64      = 32;
pub const WIRE_LOOKUP_READ_COUNTS: u64   = 33;
pub const WIRE_LOOKUP_READ_TAGS: u64     = 34;
pub const WIRE_W_L_SHIFT: u64            = 35;
pub const WIRE_W_R_SHIFT: u64            = 36;
pub const WIRE_W_O_SHIFT: u64            = 37;
pub const WIRE_W_4_SHIFT: u64            = 38;
pub const WIRE_Z_PERM_SHIFT: u64         = 39;

// Transcript library to generate fiat shamir challenges
pub struct Transcript {
    pub relation_parameters: RelationParameters,
    // NUMBER_OF_ALPHAS = 25
    pub alphas: [u256; 25],
    // CONST_PROOF_SIZE_LOG_N = 28
    pub gate_challenges: [u256; 28],
    // CONST_PROOF_SIZE_LOG_N = 28
    pub sumcheck_u_challenges: [u256; 28],
    pub rho: u256,
    pub gemini_r: u256,
    pub shplonk_nu: u256,
    pub shplonk_z: u256,
}

pub fn generate_transcript(proof: Proof, public_inputs: [u256;1], circuit_size: u256, pub_inputs_offset: u256)  -> Transcript {
    let (relation_parameters, previous_challenge0): (RelationParameters, u256) = generate_relation_parameters_challenges(proof, public_inputs, circuit_size, pub_inputs_offset);

    let (alphas, previous_challenge1): ([u256; 25], u256)  = generate_alpha_challenges(proof, previous_challenge0);

    let (gate_challenges, previous_challenge2): ([u256; 28], u256) = generate_gate_challenges(previous_challenge1);

    let (sumcheck_u_challenges, previous_challenge3): ([u256; 28], u256) = generate_sumcheck_challenges(proof, previous_challenge2);

    let (rho_challenge_elements, rho, previous_challenge4): ([u256;41], u256, u256) = generate_rho_challenge(proof, previous_challenge3);

    let (g_R, gemini_r, previous_challenge5): ([u256;109], u256, u256) = generate_gemini_R_challenge(proof, previous_challenge4);

    let (shplonk_nu_challenge_elements, shplonk_nu, previous_challenge6): ([u256; 29], u256, u256) = generate_shplonk_nu_challenge(proof, previous_challenge5);

    let (shplonk_Z_challenge, shplonk_Z, previous_challenge7): ([u256;5], u256, u256) = generate_shplonk_z_challenge(proof, previous_challenge6);

    Transcript {
        relation_parameters: relation_parameters,
        alphas: alphas,
        gate_challenges: gate_challenges,
        sumcheck_u_challenges: sumcheck_u_challenges,
        rho: rho, 
        gemini_r: gemini_r,
        shplonk_nu: shplonk_nu,
        shplonk_z: shplonk_Z
    }
}

// Takes a field element and splits it into high and low
// (the result will be in field as well)
pub fn split_challenge(challenge: u256) -> (u256, u256) {
    let lo_mask: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFu256;

    let lo: u256 = challenge & lo_mask;
    let hi: u256 = challenge >> 128;

    (lo, hi)
}

pub fn generate_relation_parameters_challenges(
  proof: Proof,
  public_inputs: [u256;1],// PUB_INPUT_SIZE = 1
  circuit_size: u256,
  pub_inputs_offset: u256,
) -> (RelationParameters, u256) {
  let eta_res = generate_eta_challenge(proof, public_inputs, circuit_size, pub_inputs_offset);
  let previous_challenge = eta_res[3];
  let beta_gamma_res = generate_beta_and_gamma_challenges(proof, previous_challenge);

  (RelationParameters {
    eta: eta_res[0],
    eta_two: eta_res[1],
    eta_three: eta_res[2],
    beta: beta_gamma_res[0],
    gamma: beta_gamma_res[1],
    public_inputs_delta: 0,
  }, beta_gamma_res[2])
}

// uses 3 + NUMBER_OF_PUBLIC_INPUTS + 12
const ROUND0_LEN: u64 = 32;
pub fn generate_eta_challenge(
    proof: Proof,
    public_inputs: [u256; 1],// PUB_INPUT_SIZE = 1
    circuit_size: u256,
    pub_inputs_offset: u256,
) -> [u256; 4] {
    let mut transcript = Bytes::new();

    // Append meta
    transcript.append(circuit_size.to_be_bytes());
    transcript.append(NUMBER_OF_PUBLIC_INPUTS.as_u256().to_be_bytes());
    transcript.append(pub_inputs_offset.to_be_bytes());

    // Public inputs
    let mut i = 0;
    while i < NUMBER_OF_PUBLIC_INPUTS - PAIRING_POINTS_SIZE {
        transcript.append(public_inputs[i].to_be_bytes());
        i += 1;
    }

    // Pairing point objects
    let mut j = 0;
    while j < PAIRING_POINTS_SIZE {
        transcript.append(proof.pairing_point_object[j].to_be_bytes());
        j += 1;
    }

    // Wires
    transcript.append(proof.w1.x[0].to_be_bytes());
    transcript.append(proof.w1.x[1].to_be_bytes());
    transcript.append(proof.w1.y[0].to_be_bytes());
    transcript.append(proof.w1.y[1].to_be_bytes());
    transcript.append(proof.w2.x[0].to_be_bytes());
    transcript.append(proof.w2.x[1].to_be_bytes());
    transcript.append(proof.w2.y[0].to_be_bytes());
    transcript.append(proof.w2.y[1].to_be_bytes());
    transcript.append(proof.w3.x[0].to_be_bytes());
    transcript.append(proof.w3.x[1].to_be_bytes());
    transcript.append(proof.w3.y[0].to_be_bytes());
    transcript.append(proof.w3.y[1].to_be_bytes());

    // Hash round 0 = previous challenge mod MODULUS
    let hash_0 = keccak256(transcript);
    let mut hash_0_field: u256 = 0;
    asm (rA: hash_0_field, rB: hash_0, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };
    let (eta, eta_two) = split_challenge(hash_0_field);

    // Next challenge input: just the previous challenge
    let hash_1 = keccak256(hash_0_field);
    let mut hash_1_field: u256 = 0;

    asm (rA: hash_1_field, rB: hash_1, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };
    let (eta_three, _) = split_challenge(hash_1_field);

    [eta, eta_two, eta_three, hash_1_field]
}

pub fn generate_beta_and_gamma_challenges(
    proof: Proof,
    previous_challenge: u256,
) -> [u256; 3] {
    let mut transcript = Bytes::new();

    // 0: the previous challenge in bytes
    transcript.append(previous_challenge.to_be_bytes());

    // 1–4: lookupReadCounts.x0, x1, y0, y1
    transcript.append(proof.lookup_read_counts.x[0].to_be_bytes());
    transcript.append(proof.lookup_read_counts.x[1].to_be_bytes());
    transcript.append(proof.lookup_read_counts.y[0].to_be_bytes());
    transcript.append(proof.lookup_read_counts.y[1].to_be_bytes());

    // 5–8: lookupReadTags.x0, x1, y0, y1
    transcript.append(proof.lookup_read_tags.x[0].to_be_bytes());
    transcript.append(proof.lookup_read_tags.x[1].to_be_bytes());
    transcript.append(proof.lookup_read_tags.y[0].to_be_bytes());
    transcript.append(proof.lookup_read_tags.y[1].to_be_bytes());

    // 9–12: w4.x0, x1, y0, y1
    transcript.append(proof.w4.x[0].to_be_bytes());
    transcript.append(proof.w4.x[1].to_be_bytes());
    transcript.append(proof.w4.y[0].to_be_bytes());
    transcript.append(proof.w4.y[1].to_be_bytes());

    // hash and reduce into field
    let next_previous = keccak256(transcript);

    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    // split out beta & gamma
    let (beta, gamma) = split_challenge(next_previous_field);

    [beta, gamma, next_previous_field]
}

pub fn generate_alpha_challenges(
  proof: Proof,
  previous_challenge: u256,
) -> ([u256; 25], u256) { // NUMBER_OF_ALPHAS = 25

    let mut transcript = Bytes::new();
    transcript.append(previous_challenge.to_be_bytes());
    transcript.append(proof.lookup_inverses.x[0].to_be_bytes());
    transcript.append(proof.lookup_inverses.x[1].to_be_bytes());
    transcript.append(proof.lookup_inverses.y[0].to_be_bytes());
    transcript.append(proof.lookup_inverses.y[1].to_be_bytes());

    transcript.append(proof.z_perm.x[0].to_be_bytes());
    transcript.append(proof.z_perm.x[1].to_be_bytes());
    transcript.append(proof.z_perm.y[0].to_be_bytes());
    transcript.append(proof.z_perm.y[1].to_be_bytes());

    // hash and reduce into field
    let mut next_previous = keccak256(transcript);

    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    // split out in alphas
    let (alpha0, alpha1) = split_challenge(next_previous_field);
    let mut alphas: [u256; 25] = [0; 25];
    alphas[0] = alpha0;
    alphas[1] = alpha1;
    let mut i = 1;
    while i < NUMBER_OF_ALPHAS/2 {
        next_previous = keccak256(next_previous_field.to_be_bytes());
        asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
            wqam rA rB rC rD;
        };
        let (alpha_next_0, alpha_next_1) = split_challenge(next_previous_field);

        alphas[2*i] = alpha_next_0;
        alphas[2*i+1] = alpha_next_1;
        i += 1;
    }

    if (((NUMBER_OF_ALPHAS & 1) == 1) && NUMBER_OF_ALPHAS > 2) {
        next_previous = keccak256(next_previous_field.to_be_bytes());
        asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
            wqam rA rB rC rD;
        };
        let (alpha_next_0, unused) = split_challenge(next_previous_field);
        alphas[NUMBER_OF_ALPHAS-1] = alpha_next_0;
    }

    (alphas, next_previous_field)
}

// CONST_PROOF_SIZE_LOG_N = 28
pub fn generate_gate_challenges(previous_challenge: u256) -> ([u256; 28], u256) {
    let mut i = 0;
    let mut temp_previous_challenge_field: u256 = previous_challenge;
    let mut gate_challenges: [u256; 28] = [0u256;28];
    while i < CONST_PROOF_SIZE_LOG_N {
      let hash = keccak256(temp_previous_challenge_field.to_be_bytes());
      asm (rA: temp_previous_challenge_field, rB: hash, rC: ZERO, rD: MODULUS) {
          wqam rA rB rC rD;
      };
      let (gate_challenge, unused) = split_challenge(temp_previous_challenge_field);
      gate_challenges[i] = gate_challenge;
      i += 1; 
    }
    (gate_challenges, temp_previous_challenge_field)
}

// CONST_PROOF_SIZE_LOG_N = 28
pub fn generate_sumcheck_challenges(proof: Proof, prev_challenge: u256) -> ([u256; 28], u256) {
    let mut i = 0;
    let mut prev_challenge_field = prev_challenge;
    let mut sumcheck_challenges: [u256; 28] = [0;28];
    while i < CONST_PROOF_SIZE_LOG_N {
      let mut transcript = Bytes::new();
      transcript.append(prev_challenge_field.to_be_bytes());
      let mut j = 0;
      while j < BATCHED_RELATION_PARTIAL_LENGTH {
          transcript.append(proof.sumcheck_univariates[i][j].to_be_bytes());
          j += 1;
      }
      let hash = keccak256(transcript);
      asm (rA: prev_challenge_field, rB: hash, rC: ZERO, rD: MODULUS) {
          wqam rA rB rC rD;
      };
      let (sumcheck_challenge_i, unused) = split_challenge(prev_challenge_field);
      sumcheck_challenges[i] = sumcheck_challenge_i;
      i += 1;
    }
    (sumcheck_challenges, prev_challenge_field)
}

// NUMBER_OF_ENTITIES = 40, length of array is +1
pub fn generate_rho_challenge(proof: Proof, next_previous_challenge: u256) -> ([u256;41], u256, u256) {
    let mut rho_challenge_elements: [u256; 41] = [0u256;41];
    let mut transcript = Bytes::new();
    rho_challenge_elements[0] = next_previous_challenge;
    transcript.append(next_previous_challenge.to_be_bytes());
    let mut i = 0;
    while i < NUMBER_OF_ENTITIES {
        rho_challenge_elements[i+1] = proof.sumcheck_evaluations[i];
        transcript.append(proof.sumcheck_evaluations[i].to_be_bytes());
        i += 1;
    }
    // hash and reduce into field
    let next_previous = keccak256(transcript);

    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    let (rho, unused) = split_challenge(next_previous_field);
    (rho_challenge_elements, rho, next_previous_field)
}

// 109 = (CONST_PROOF_SIZE_LOG_N - 1) * 4 + 1
pub fn generate_gemini_R_challenge(proof: Proof, prev_challenge: u256) -> ([u256;109], u256, u256) {
    let mut g_R: [u256;109] = [0u256; 109];
    let mut transcript = Bytes::new();
    g_R[0] = prev_challenge;
    transcript.append(prev_challenge.to_be_bytes());
    let mut i = 0;
    while i < CONST_PROOF_SIZE_LOG_N_MINUS_1 {
        g_R[1+i*4] = proof.gemini_fold_comms[i].x[0];
        g_R[2+i*4] = proof.gemini_fold_comms[i].x[1];
        g_R[3+i*4] = proof.gemini_fold_comms[i].y[0];
        g_R[4+i*4] = proof.gemini_fold_comms[i].y[1];
        transcript.append(proof.gemini_fold_comms[i].x[0].to_be_bytes());
        transcript.append(proof.gemini_fold_comms[i].x[1].to_be_bytes());
        transcript.append(proof.gemini_fold_comms[i].y[0].to_be_bytes());
        transcript.append(proof.gemini_fold_comms[i].y[1].to_be_bytes());
        i += 1;
    }
    // hash and reduce into field
    let next_previous = keccak256(transcript);

    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    let (gemini_R, unused) = split_challenge(next_previous_field);
    (g_R, gemini_R, next_previous_field)
}

// 29 = (CONST_PROOF_SIZE_LOG_N) + 1
pub fn generate_shplonk_nu_challenge(proof: Proof, prev_challenge: u256) -> ([u256; 29], u256, u256) {
  // CONST_PROOF_SIZE_LOG_N + 1
    let mut shplonk_nu_challenge_elements: [u256; 29] = [0u256; 29];
    let mut transcript = Bytes::new();
    shplonk_nu_challenge_elements[0] = prev_challenge;
    transcript.append(prev_challenge.to_be_bytes());
    let mut i = 0;
    while i < CONST_PROOF_SIZE_LOG_N {
        shplonk_nu_challenge_elements[i+1] = proof.gemini_a_evaluations[i];
        transcript.append(proof.gemini_a_evaluations[i].to_be_bytes());
        i += 1;
    }
    let next_previous = keccak256(transcript);

    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    let (shplonk_nu, unused) = split_challenge(next_previous_field);
    (shplonk_nu_challenge_elements, shplonk_nu, next_previous_field)
}

// fixed 5
pub fn generate_shplonk_z_challenge(proof: Proof, prev_challenge: u256) -> ([u256;5], u256, u256) {
    let mut shplonk_Z_challenge: [u256;5] = [0u256;5];
    let mut transcript = Bytes::new();
    shplonk_Z_challenge[0] = prev_challenge;
    shplonk_Z_challenge[1] = proof.shplonk_q.x[0];
    shplonk_Z_challenge[2] = proof.shplonk_q.x[1];
    shplonk_Z_challenge[3] = proof.shplonk_q.y[0];
    shplonk_Z_challenge[4] = proof.shplonk_q.y[1];
    let mut i = 0;
    while i < 5 {
        transcript.append(shplonk_Z_challenge[i].to_be_bytes());
        i += 1;
    }
    let next_previous = keccak256(transcript);
    let mut next_previous_field: u256 = 0;
    asm (rA: next_previous_field, rB: next_previous, rC: ZERO, rD: MODULUS) {
        wqam rA rB rC rD;
    };

    let (shplonk_Z, unused) = split_challenge(next_previous_field);
    (shplonk_Z_challenge, shplonk_Z, next_previous_field)
}

const NEG_HALF_MODULO_P: u256 = 0x183227397098d014dc2822db40c0ac2e9419f4243cdcb848a1f0fac9f8000000u256; 

// 40 = NUMBER_OF_ENTITIES
// In Sway we use constant values for indices instead of enums
pub fn accumulate_arithmetic_relation(p: [u256; 40], domain_sep: u256) -> (u256, u256) {
    let q_arith: u256 = p[WIRE_Q_ARITH];
    
    // Relation 0
    let mut accum0: u256 = (q_arith.submod(3))
    .mulmod(
      p[WIRE_Q_M].mulmod(
        p[WIRE_W_R].mulmod(
          p[WIRE_W_L].mulmod(
            NEG_HALF_MODULO_P))));
    
    accum0 = accum0.addmod(p[WIRE_Q_L].mulmod(p[WIRE_W_L]))
      .addmod(p[WIRE_Q_R].mulmod(p[WIRE_W_R]))
      .addmod(p[WIRE_Q_O].mulmod(p[WIRE_W_O]))
      .addmod(p[WIRE_Q_4].mulmod(p[WIRE_W_4]))
      .addmod(p[WIRE_Q_C]);

    accum0 = accum0.addmod((q_arith.submod(1)).mulmod(p[WIRE_W_4_SHIFT]));
    accum0 = accum0.mulmod(q_arith);
    accum0 = accum0.mulmod(domain_sep); 

    // Relation 1
    let mut accum1 = p[WIRE_W_L].addmod(p[WIRE_W_4]).submod(p[WIRE_W_L_SHIFT]).addmod(p[WIRE_Q_M]);
    accum1 = accum1.mulmod(q_arith.submod(2));
    accum1 = accum1.mulmod(q_arith.submod(1));
    accum1 = accum1.mulmod(q_arith);
    accum1 = accum1.mulmod(domain_sep);

    (accum0, accum1)
}

// 16 = PAIRING_POINTS_SIZE
// 1 = PUB_INPUT_SIZE
pub fn compute_public_input_delta(public_inputs: [u256; 1], pairing_point_object: [u256; 16], beta: u256, gamma: u256, offset: u256) -> u256 {
    
    let mut numerator: u256 = 1u256;
    let mut denominator: u256 = 1u256;
    let mut numerator_acc: u256 = gamma.addmod(beta.mulmod(N.addmod(offset)));
    let mut denominator_acc: u256 = gamma.submod(beta.mulmod(offset.addmod(1u256)));

    let mut i = 0;
    while i < (NUMBER_OF_PUBLIC_INPUTS - PAIRING_POINTS_SIZE) {
        let pub_input = public_inputs[i];
        numerator = numerator.mulmod(numerator_acc.addmod(pub_input));
        denominator = denominator.mulmod(denominator_acc.addmod(pub_input));
        numerator_acc = numerator_acc.addmod(beta);
        denominator_acc = denominator_acc.submod(beta);
        i += 1;
    }

    i = 0;

    while i < PAIRING_POINTS_SIZE {
        let pub_input = pairing_point_object[i];
        numerator = numerator.mulmod(numerator_acc.addmod(pub_input));
        denominator = denominator.mulmod(denominator_acc.addmod(pub_input));
        numerator_acc = numerator_acc.addmod(beta);
        denominator_acc = denominator_acc.submod(beta);
        i += 1;
    }
    denominator = inverse(denominator);
    numerator.mulmod(denominator)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_permutation_relation(
  p: [u256; 40], 
  rp: RelationParameters, 
  domain_sep: u256, 
  public_inputs_delta: u256) -> (u256, u256) {
    let mut grand_product_numerator = 0u256;
    let mut grand_product_denominator = 0u256;

    let mut num: u256 = p[WIRE_W_L].addmod((p[WIRE_ID_1]).mulmod(rp.beta)).addmod(rp.gamma);
    num = num.mulmod(p[WIRE_W_R].addmod(p[WIRE_ID_2].mulmod(rp.beta)).addmod(rp.gamma));
    num = num.mulmod(p[WIRE_W_O].addmod(p[WIRE_ID_3].mulmod(rp.beta)).addmod(rp.gamma));
    num = num.mulmod(p[WIRE_W_4].addmod(p[WIRE_ID_4].mulmod(rp.beta)).addmod(rp.gamma));
    grand_product_numerator = num;

    let mut den: u256 = p[WIRE_W_L].addmod((p[WIRE_SIGMA_1]).mulmod(rp.beta)).addmod(rp.gamma);
    den = den.mulmod(p[WIRE_W_R].addmod(p[WIRE_SIGMA_2].mulmod(rp.beta)).addmod(rp.gamma));
    den = den.mulmod(p[WIRE_W_O].addmod(p[WIRE_SIGMA_3].mulmod(rp.beta)).addmod(rp.gamma));
    den = den.mulmod(p[WIRE_W_4].addmod(p[WIRE_SIGMA_4].mulmod(rp.beta)).addmod(rp.gamma));
    grand_product_denominator = den;

    // Contribution 2
    let mut acc2: u256 = (p[WIRE_Z_PERM].addmod(p[WIRE_LAGRANGE_FIRST])).mulmod(grand_product_numerator);
    acc2 = acc2.submod((p[WIRE_Z_PERM_SHIFT].addmod(p[WIRE_LAGRANGE_LAST].mulmod(public_inputs_delta))).mulmod(grand_product_denominator));
    acc2 = acc2.mulmod(domain_sep);

    // Contribution 3
    let acc3 = p[WIRE_LAGRANGE_LAST].mulmod(p[WIRE_Z_PERM_SHIFT]).mulmod(domain_sep);

    (acc2, acc3)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_log_derivative_lookup_relation(  
  p: [u256; 40], 
  rp: RelationParameters,
  domain_sep: u256) -> (u256, u256) {
    let mut write_term = 0u256;
    let mut read_term = 0u256;

    write_term = p[WIRE_TABLE_1]
      .addmod(rp.gamma)
      .addmod(p[WIRE_TABLE_2].mulmod(rp.eta))
      .addmod(p[WIRE_TABLE_3].mulmod(rp.eta_two))
      .addmod(p[WIRE_TABLE_4].mulmod(rp.eta_three));

    let derived_entry_1: u256 = p[WIRE_W_L]
      .addmod(rp.gamma)
      .addmod(p[WIRE_Q_R].mulmod(p[WIRE_W_L_SHIFT]));

    let derived_entry_2: u256 = p[WIRE_W_R]
      .addmod(p[WIRE_Q_M].mulmod(p[WIRE_W_R_SHIFT]));

    let derived_entry_3: u256 = p[WIRE_W_O]
      .addmod(p[WIRE_Q_C].mulmod(p[WIRE_W_O_SHIFT]));

    read_term = derived_entry_1
      .addmod(derived_entry_2.mulmod(rp.eta))
      .addmod(derived_entry_3.mulmod(rp.eta_two))
      .addmod(p[WIRE_Q_O].mulmod(rp.eta_three));

    let read_inverse: u256 = p[WIRE_LOOKUP_INVERSES].mulmod(write_term);
    let write_inverse: u256 = p[WIRE_LOOKUP_INVERSES].mulmod(read_term);

    let inverse_exists_xor: u256 = p[WIRE_LOOKUP_READ_TAGS]
      .addmod(p[WIRE_Q_LOOKUP])
      .submod(p[WIRE_LOOKUP_READ_TAGS].mulmod(p[WIRE_Q_LOOKUP]));

    // Inverse calculated correctly relation
    let mut accumulator_none: u256 = read_term.mulmod(write_term).mulmod(p[WIRE_LOOKUP_INVERSES]);
    accumulator_none = accumulator_none.submod(inverse_exists_xor);
    accumulator_none = accumulator_none.mulmod(domain_sep);

    // Inverse
    let accumulator_one: u256 = p[WIRE_Q_LOOKUP].mulmod(read_inverse)
      .submod(p[WIRE_LOOKUP_READ_COUNTS].mulmod(write_inverse));
    (accumulator_none, accumulator_one)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_delta_range_relation(
    p: [u256; 40],
    domain_sep: u256,
) -> (u256, u256, u256, u256) {
    let minus_one: u256 = MINUS_ONE;
    let minus_two: u256 = minus_one.submod(1u256);
    let minus_three: u256 = minus_one.submod(2u256);

    // Wire deltas
    let delta_1: u256 = p[WIRE_W_R].submod(p[WIRE_W_L]);
    let delta_2: u256 = p[WIRE_W_O].submod(p[WIRE_W_R]);
    let delta_3: u256 = p[WIRE_W_4].submod(p[WIRE_W_O]);
    let delta_4: u256 = p[WIRE_W_L_SHIFT].submod(p[WIRE_W_4]);

    // Contribution 6
    let mut acc6: u256 = delta_1;
    acc6 = acc6.mulmod(delta_1.addmod(minus_one));
    acc6 = acc6.mulmod(delta_1.addmod(minus_two));
    acc6 = acc6.mulmod(delta_1.addmod(minus_three));
    acc6 = acc6.mulmod(p[WIRE_Q_RANGE]);
    acc6 = acc6.mulmod(domain_sep);

    // Contribution 7
    let mut acc7: u256 = delta_2;
    acc7 = acc7.mulmod(delta_2.addmod(minus_one));
    acc7 = acc7.mulmod(delta_2.addmod(minus_two));
    acc7 = acc7.mulmod(delta_2.addmod(minus_three));
    acc7 = acc7.mulmod(p[WIRE_Q_RANGE]);
    acc7 = acc7.mulmod(domain_sep);

    // Contribution 8
    let mut acc8: u256 = delta_3;
    acc8 = acc8.mulmod(delta_3.addmod(minus_one));
    acc8 = acc8.mulmod(delta_3.addmod(minus_two));
    acc8 = acc8.mulmod(delta_3.addmod(minus_three));
    acc8 = acc8.mulmod(p[WIRE_Q_RANGE]);
    acc8 = acc8.mulmod(domain_sep);

    // Contribution 9
    let mut acc9: u256 = delta_4;
    acc9 = acc9.mulmod(delta_4.addmod(minus_one));
    acc9 = acc9.mulmod(delta_4.addmod(minus_two));
    acc9 = acc9.mulmod(delta_4.addmod(minus_three));
    acc9 = acc9.mulmod(p[WIRE_Q_RANGE]);
    acc9 = acc9.mulmod(domain_sep);

    (acc6, acc7, acc8, acc9)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_elliptic_relation(
    p: [u256; 40],
    domain_sep: u256,
) -> (u256, u256) {
    // elliptic parameters
    let x1 = p[WIRE_W_R];
    let y1 = p[WIRE_W_O];

    let x2 = p[WIRE_W_L_SHIFT];
    let y2 = p[WIRE_W_4_SHIFT];
    let y3 = p[WIRE_W_O_SHIFT];
    let x3 = p[WIRE_W_R_SHIFT];

    let q_sign = p[WIRE_Q_L];
    let q_is_double = p[WIRE_Q_M];
    let q_elliptic = p[WIRE_Q_ELLIPTIC];

    let x_diff = x2.submod(x1);
    let y1_sqr = y1.mulmod(y1);

    let one_minus_q_is_double = (1u256.submod(q_is_double));

    // Contribution 10 point addition, x-coordinate check
    let y2_sqr = y2.mulmod(y2);
    let y1y2_q = y1.mulmod(y2).mulmod(q_sign);
    let mut x_add_identity =
        (x3.addmod(x2).addmod(x1))
        .mulmod(x_diff.mulmod(x_diff));
    x_add_identity = x_add_identity
        .submod(y2_sqr)
        .submod(y1_sqr)
        .addmod(y1y2_q).addmod(y1y2_q);

    let mut eval10 =
        x_add_identity
        .mulmod(domain_sep)
        .mulmod(q_elliptic)
        .mulmod(one_minus_q_is_double);

    // Contribution 11 point addition, x-coordinate check
    let y1_plus_y3 = y1.addmod(y3);
    let y_diff = y2.mulmod(q_sign).submod(y1);
    let y_add_identity =
        y1_plus_y3.mulmod(x_diff)
        .addmod( (x3.submod(x1)).mulmod(y_diff));

    let mut eval11 =
        y_add_identity
        .mulmod(domain_sep)
        .mulmod(q_elliptic)
        .mulmod(one_minus_q_is_double);

    // Contribution 10 point doubling, x-coordinate check
    let x_pow_4 = (y1_sqr.addmod(17u256)).mulmod(x1);
    let mut y1_sqr_mul_4 = y1_sqr.addmod(y1_sqr);
    y1_sqr_mul_4 = y1_sqr_mul_4.addmod(y1_sqr_mul_4);
    let x1_pow_4_mul_9 = x_pow_4.mulmod(9u256);

    let x_double_identity =
        (x3.addmod(x1).addmod(x1)).mulmod(y1_sqr_mul_4)
        .submod(x1_pow_4_mul_9);

    eval10 = eval10.addmod(
        x_double_identity
            .mulmod(domain_sep)
            .mulmod(q_elliptic)
            .mulmod(q_is_double)
    );

    // Contribution 11 point doubling, y-coordinate check
    let x1_sqr_mul_3 = (x1.addmod(x1).addmod(x1)).mulmod(x1);
    let y_double_identity =
        x1_sqr_mul_3.mulmod(x1.submod(x3))
        .submod( (y1.addmod(y1)).mulmod(y1.addmod(y3)));

    eval11 = eval11.addmod(
        y_double_identity
            .mulmod(domain_sep)
            .mulmod(q_elliptic)
            .mulmod(q_is_double)
    );

    (eval10, eval11)
}

const SUBLIMB_SHIFT: u256 = 0x4000u256;
const LIMB_SIZE:    u256 = 0x100000000000000000u256;

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_auxiliary_relation(
    p: [u256; 40],
    rp: RelationParameters,
    domain_sep: u256,
) -> (u256, u256, u256, u256, u256, u256) {
    let qL = p[WIRE_Q_L];
    let qR = p[WIRE_Q_R];
    let qO = p[WIRE_Q_O];
    let qM = p[WIRE_Q_M];
    let q4 = p[WIRE_Q_4];
    let qAux = p[WIRE_Q_AUX];
    let qArith = p[WIRE_Q_ARITH];

    let qLR = qL.mulmod(qR);
    let auxSep = qAux.mulmod(domain_sep);

    // Non-native field arithmetic
    let mut limb_subproduct =
        (p[WIRE_W_L].mulmod(p[WIRE_W_R_SHIFT])).addmod(p[WIRE_W_L_SHIFT].mulmod(p[WIRE_W_R]));

    let mut nnf_gate_2 =
          (p[WIRE_W_L].mulmod(p[WIRE_W_4]))
        .addmod(p[WIRE_W_R].mulmod(p[WIRE_W_O]))
        .submod(p[WIRE_W_O_SHIFT]);
    nnf_gate_2 = nnf_gate_2.mulmod(LIMB_SIZE);
    nnf_gate_2 = nnf_gate_2.submod(p[WIRE_W_4_SHIFT]);
    nnf_gate_2 = nnf_gate_2.addmod(limb_subproduct);
    nnf_gate_2 = nnf_gate_2.mulmod(q4);

    limb_subproduct = limb_subproduct.mulmod(LIMB_SIZE);
    limb_subproduct = limb_subproduct.addmod(p[WIRE_W_L_SHIFT].mulmod(p[WIRE_W_R_SHIFT]));

    let mut nnf_gate_1 = limb_subproduct.submod(p[WIRE_W_O].addmod(p[WIRE_W_4]));
    nnf_gate_1 = nnf_gate_1.mulmod(qO);

    let mut nnf_gate_3 = limb_subproduct.addmod(p[WIRE_W_4]);
    nnf_gate_3 = nnf_gate_3.submod(p[WIRE_W_O_SHIFT].addmod(p[WIRE_W_4_SHIFT]));
    nnf_gate_3 = nnf_gate_3.mulmod(qM);

    let mut non_native_field_identity = nnf_gate_1.addmod(nnf_gate_2).addmod(nnf_gate_3);
    non_native_field_identity = non_native_field_identity.mulmod(qR);

    // ((((w2' * 2^14 + w1') * 2^14 + w3) * 2^14 + w2) * 2^14 + w1 - w4) * qm
    let mut limb_acc_1 = p[WIRE_W_R_SHIFT].mulmod(SUBLIMB_SHIFT);
    limb_acc_1 = (limb_acc_1.addmod(p[WIRE_W_L_SHIFT])).mulmod(SUBLIMB_SHIFT);
    limb_acc_1 = (limb_acc_1.addmod(p[WIRE_W_O])).mulmod(SUBLIMB_SHIFT);
    limb_acc_1 = (limb_acc_1.addmod(p[WIRE_W_R])).mulmod(SUBLIMB_SHIFT);
    limb_acc_1 = (limb_acc_1.addmod(p[WIRE_W_L]).submod(p[WIRE_W_4])).mulmod(q4);

    // ((((w3' * 2^14 + w2') * 2^14 + w1') * 2^14 + w4) * 2^14 + w3 - w4') * qm
    let mut limb_acc_2 = p[WIRE_W_O_SHIFT].mulmod(SUBLIMB_SHIFT);
    limb_acc_2 = (limb_acc_2.addmod(p[WIRE_W_R_SHIFT])).mulmod(SUBLIMB_SHIFT);
    limb_acc_2 = (limb_acc_2.addmod(p[WIRE_W_L_SHIFT])).mulmod(SUBLIMB_SHIFT);
    limb_acc_2 = (limb_acc_2.addmod(p[WIRE_W_4])).mulmod(SUBLIMB_SHIFT);
    limb_acc_2 = (limb_acc_2.addmod(p[WIRE_W_O]).submod(p[WIRE_W_4_SHIFT])).mulmod(qM);

    let mut limb_acc_identity = limb_acc_1.addmod(limb_acc_2);
    limb_acc_identity = limb_acc_identity.mulmod(qO);

    // Memory record check
    // qc + w1*eta + w2*eta_two + w3*eta_three − w4
    let mut memory_record_check = p[WIRE_W_O].mulmod(rp.eta_three);
    memory_record_check = memory_record_check.addmod(p[WIRE_W_R].mulmod(rp.eta_two));
    memory_record_check = memory_record_check.addmod(p[WIRE_W_L].mulmod(rp.eta));
    memory_record_check = memory_record_check.addmod(p[WIRE_Q_C]);
    let partial_record_check = memory_record_check;
    memory_record_check = memory_record_check.submod(p[WIRE_W_4]);

    let index_delta  = p[WIRE_W_L_SHIFT].submod(p[WIRE_W_L]);
    let record_delta = p[WIRE_W_4_SHIFT].submod(p[WIRE_W_4]);

    let index_is_monotonic =
        (index_delta.mulmod(index_delta)).submod(index_delta);

    let adj_vals_if_adj_idx =
        ((index_delta.mulmod(MINUS_ONE)).addmod(1u256)).mulmod(record_delta);

    let eval13 =
        adj_vals_if_adj_idx.mulmod(qLR).mulmod(auxSep);
    let eval14 =
        index_is_monotonic.mulmod(qLR).mulmod(auxSep);

    let rom_consistency_check_identity = memory_record_check.mulmod(qLR);

    // RAM consistency
    let access_type = p[WIRE_W_4].submod(partial_record_check);
    let access_check = (access_type.mulmod(access_type)).submod(access_type);

    let mut next_gate_access_type =
          (p[WIRE_W_O_SHIFT].mulmod(rp.eta_three))
        .addmod(p[WIRE_W_R_SHIFT].mulmod(rp.eta_two))
        .addmod(p[WIRE_W_L_SHIFT].mulmod(rp.eta));
    next_gate_access_type = p[WIRE_W_4_SHIFT].submod(next_gate_access_type);

    let value_delta = p[WIRE_W_O_SHIFT].submod(p[WIRE_W_O]);

    let mut adj_vals_if_adj_idx_and_next_is_read =
        (index_delta.mulmod(MINUS_ONE)).addmod(1u256);
    adj_vals_if_adj_idx_and_next_is_read = adj_vals_if_adj_idx_and_next_is_read.mulmod(value_delta);
    adj_vals_if_adj_idx_and_next_is_read = adj_vals_if_adj_idx_and_next_is_read.mulmod((next_gate_access_type.mulmod(MINUS_ONE)).addmod(1u256));

    let next_gate_access_is_bool =
        (next_gate_access_type.mulmod(next_gate_access_type)).submod(next_gate_access_type);

    let eval15 = adj_vals_if_adj_idx_and_next_is_read.mulmod(qArith).mulmod(auxSep);
    let eval16 = index_is_monotonic.mulmod(qArith).mulmod(auxSep);
    let eval17 = next_gate_access_is_bool.mulmod(qArith).mulmod(auxSep);

    let ram_consistency_check_identity = access_check.mulmod(qArith);

    // Let delta_index = index_{i + 1} - index_{i}
    // Iff delta_index == 0, timestamp_check = timestamp_{i + 1} - timestamp_i
    // Else timestamp_check = 0
    let timestamp_delta = p[WIRE_W_R_SHIFT].submod(p[WIRE_W_R]);
    let mut ram_timestamp_check_identity =
        (index_delta.mulmod(MINUS_ONE)).addmod(1u256);
    ram_timestamp_check_identity = ram_timestamp_check_identity.mulmod(timestamp_delta);
    ram_timestamp_check_identity = ram_timestamp_check_identity.submod(p[WIRE_W_O]);

    let mut memory_identity =
          rom_consistency_check_identity;
    memory_identity = memory_identity.addmod(ram_timestamp_check_identity.mulmod(q4.mulmod(qL)));
    memory_identity = memory_identity.addmod(memory_record_check.mulmod(qM.mulmod(qL)));
    memory_identity = memory_identity.addmod(ram_consistency_check_identity);

    // (deg 3 or 9) + (deg 4) + (deg 3)
    let auxiliary_identity =
        memory_identity.addmod(non_native_field_identity).addmod(limb_acc_identity);

    let eval12 = auxiliary_identity.mulmod(auxSep);

    (eval12, eval13, eval14, eval15, eval16, eval17)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_poseidon_external_relation(
    p: [u256; 40],
    domain_sep: u256,
) -> (u256, u256, u256, u256) {
    let s1 = p[WIRE_W_L].addmod(p[WIRE_Q_L]);
    let s2 = p[WIRE_W_R].addmod(p[WIRE_Q_R]);
    let s3 = p[WIRE_W_O].addmod(p[WIRE_Q_O]);
    let s4 = p[WIRE_W_4].addmod(p[WIRE_Q_4]);

    let u1 = s1.mulmod(s1).mulmod(s1).mulmod(s1).mulmod(s1);
    let u2 = s2.mulmod(s2).mulmod(s2).mulmod(s2).mulmod(s2);
    
    let u3 = s3.mulmod(s3).mulmod(s3).mulmod(s3).mulmod(s3);
    let u4 = s4.mulmod(s4).mulmod(s4).mulmod(s4).mulmod(s4);

    // matrix mul v = M_E * u with 14 additions
    let t0 = u1.addmod(u2); // u_1 + u_2
    let t1 = u3.addmod(u4); // u_3 + u_4

    let mut t2 = u2.addmod(u2); // 2u_2
    t2 = t2.addmod(t1); // 2u_2 + u_3 + u_4

    let mut t3 = u4.addmod(u4); // 2u_4
    t3 = t3.addmod(t0); // u_1 + u_2 + 2u_4

    let mut v4 = t1.addmod(t1);
    v4 = v4.addmod(v4).addmod(t3); // u_1 + u_2 + 4u_3 + 6u_4

    let mut v2 = t0.addmod(t0);
    v2 = v2.addmod(v2).addmod(t2); // 4u_1 + 6u_2 + u_3 + u_4

    let v1 = t3.addmod(v2); // 5u_1 + 7u_2 + u_3 + 3u_4
    let v3 = t2.addmod(v4); // u_1 + 3u_2 + 5u_3 + 7u_4

    let q_pos_by_scaling = p[WIRE_Q_POSEIDON2_EXTERNAL].mulmod(domain_sep);

    let eval18 = q_pos_by_scaling.mulmod(v1.submod(p[WIRE_W_L_SHIFT]));
    let eval19 = q_pos_by_scaling.mulmod(v2.submod(p[WIRE_W_R_SHIFT]));
    let eval20 = q_pos_by_scaling.mulmod(v3.submod(p[WIRE_W_O_SHIFT]));
    let eval21 = q_pos_by_scaling.mulmod(v4.submod(p[WIRE_W_4_SHIFT]));

    (eval18, eval19, eval20, eval21)
}

// 40 = NUMBER_OF_ENTITIES
pub fn accumulate_poseidon_internal_relation(
    p: [u256; 40],
    domain_sep: u256,
) -> (u256, u256, u256, u256) {
    let INTERNAL_MATRIX_DIAGONAL: [u256; 4] = [
        0x10dc6e9c006ea38b04b1e03b4bd9490c0d03f98929ca1d7fb56821fd19d3b6e7u256,
        0x0c28145b6a44df3e0149b3d0a30b3bb599df9756d4dd9b84a86b38cfb45a740bu256,
        0x00544b8338791518b2c7645a50392798b21f75bb60e3596170067d00141cac15u256,
        0x222c01175718386f2e2e82eb122789e352e105a3b8fa852613bc534433ee428bu256
    ];

    // add round constants
    let s1 = p[WIRE_W_L].addmod(p[WIRE_Q_L]);

    // apply s-box round
    let u1 = s1.mulmod(s1).mulmod(s1).mulmod(s1).mulmod(s1);
    let u2 = p[WIRE_W_R];
    let u3 = p[WIRE_W_O];
    let u4 = p[WIRE_W_4];

    // matrix mul with v = M_I * u 4 muls and 7 additions
    let u_sum = u1.addmod(u2).addmod(u3).addmod(u4);

    let q_pos_by_scaling = p[WIRE_Q_POSEIDON2_INTERNAL].mulmod(domain_sep);

    let v1 = u1.mulmod(INTERNAL_MATRIX_DIAGONAL[0]).addmod(u_sum);
    let eval22 = q_pos_by_scaling.mulmod(v1.submod(p[WIRE_W_L_SHIFT]));

    let v2 = u2.mulmod(INTERNAL_MATRIX_DIAGONAL[1]).addmod(u_sum);
    let eval23 = q_pos_by_scaling.mulmod(v2.submod(p[WIRE_W_R_SHIFT]));

    let v3 = u3.mulmod(INTERNAL_MATRIX_DIAGONAL[2]).addmod(u_sum);
    let eval24 = q_pos_by_scaling.mulmod(v3.submod(p[WIRE_W_O_SHIFT]));

    let v4 = u4.mulmod(INTERNAL_MATRIX_DIAGONAL[3]).addmod(u_sum);
    let eval25 = q_pos_by_scaling.mulmod(v4.submod(p[WIRE_W_4_SHIFT]));

    (eval22, eval23, eval24, eval25)
}

// 26 = NUMBER_OF_SUBRELATIONS
// 25 = NUMBER_OF_ALPHAS
pub fn scale_and_batch_subrelations(
    evaluations: [u256; 26],
    subrelation_challenges: [u256; 25],
) -> u256 {
    let mut accumulator = evaluations[0];

    let mut i = 1;
    while i < NUMBER_OF_SUBRELATIONS {
        accumulator = accumulator.addmod(evaluations[i].mulmod(subrelation_challenges[i - 1]));
        i += 1;
    }

    accumulator
}

// 40 = NUMBER_OF_ENTITIES
// 25 = NUMBER_OF_ALPHAS
pub fn accumulate_relation_evaluations(  
  p: [u256; 40],
  rp: RelationParameters,
  alphas: [u256; 25],
  pow_partial_evaluation: u256) -> u256 {
    let (evals_0, evals_1) = accumulate_arithmetic_relation(p, pow_partial_evaluation);
    let (evals_2, evals_3): (u256, u256) = accumulate_permutation_relation(p, rp, pow_partial_evaluation, rp.public_inputs_delta);
    let (evals_4, evals_5): (u256, u256) = accumulate_log_derivative_lookup_relation(p, rp, pow_partial_evaluation);
    let (evals_6, evals_7, evals_8, evals_9): (u256, u256, u256, u256) = accumulate_delta_range_relation(p, pow_partial_evaluation);
    let (evals_10, evals_11): (u256, u256) = accumulate_elliptic_relation(p, pow_partial_evaluation);
    let (evals_12, evals_13, evals_14, evals_15, evals_16, evals_17): (u256, u256, u256, u256, u256, u256) = accumulate_auxiliary_relation(p, rp, pow_partial_evaluation);
    let (evals_18, evals_19, evals_20, evals_21): (u256, u256, u256, u256) = accumulate_poseidon_external_relation(p, pow_partial_evaluation);
    let (evals_22, evals_23, evals_24, evals_25): (u256, u256, u256, u256) = accumulate_poseidon_internal_relation(p, pow_partial_evaluation);
    let mut evaluations: [u256; 26] = [0u256; 26];
    evaluations[0]  = evals_0;
    evaluations[1]  = evals_1;
    evaluations[2]  = evals_2;
    evaluations[3]  = evals_3;
    evaluations[4]  = evals_4;
    evaluations[5]  = evals_5;
    evaluations[6]  = evals_6;
    evaluations[7]  = evals_7;
    evaluations[8]  = evals_8;
    evaluations[9]  = evals_9;
    evaluations[10] = evals_10;
    evaluations[11] = evals_11;
    evaluations[12] = evals_12;
    evaluations[13] = evals_13;
    evaluations[14] = evals_14;
    evaluations[15] = evals_15;
    evaluations[16] = evals_16;
    evaluations[17] = evals_17;
    evaluations[18] = evals_18;
    evaluations[19] = evals_19;
    evaluations[20] = evals_20;
    evaluations[21] = evals_21;
    evaluations[22] = evals_22;
    evaluations[23] = evals_23;
    evaluations[24] = evals_24;
    evaluations[25] = evals_25;

    scale_and_batch_subrelations(evaluations, alphas)
}

// 8 = BATCHED_RELATION_PARTIAL_LENGTH
pub fn compute_next_target_sum(
    round_univariates: [u256; 8],
    round_challenge: u256,
) -> u256 {
    let BARYCENTRIC_LAGRANGE_DENOMINATORS: [u256; 8] = [ // BATCHED_RELATION_PARTIAL_LENGTH
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffec51u256,
        0x02d0u256,
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffff11u256,
        0x0090u256,
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffff71u256,
        0x00f0u256,
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593effffd31u256,
        0x13b0u256
    ];

    // Performing Barycentric evaluations
    // Compute B(x)
    let mut numerator_value = 1u256;
    let mut i = 0;
    while i < BATCHED_RELATION_PARTIAL_LENGTH {
        numerator_value = numerator_value.mulmod(
            round_challenge.submod(i.as_u256())
        );
        i += 1;
    }

    // Calculate domain size N of inverses
    let mut denominator_inverses: [u256; 8] = [0u256; 8]; // BATCHED_RELATION_PARTIAL_LENGTH
    i = 0;
    while i < BATCHED_RELATION_PARTIAL_LENGTH {
        let mut inv = BARYCENTRIC_LAGRANGE_DENOMINATORS[i];
        inv = inv.mulmod(round_challenge.submod(i.as_u256()));
        inv = inverse(inv);
        denominator_inverses[i] = inv;
        i += 1;
    }

    let mut target_sum = 0u256;
    i = 0;
    while i < BATCHED_RELATION_PARTIAL_LENGTH {
        let term = round_univariates[i].mulmod(denominator_inverses[i]);
        target_sum = target_sum.addmod(term);
        i += 1;
    }

    // Scale the sum by the value of B(x)
    target_sum = target_sum.mulmod(numerator_value);

    target_sum
}

pub fn partially_evaluate_pow(
    gate_challenge: u256,
    current_evaluation: u256,
    round_challenge: u256,
) -> u256 {
    let univariate_eval = 1u256.addmod(
        round_challenge.mulmod(
            gate_challenge.submod(1u256)
        )
    );
    current_evaluation.mulmod(univariate_eval)
}

// 8 = BATCHED_RELATION_PARTIAL_LENGTH
pub fn check_sum(
    round_univariate: [u256; 8],
    round_target: u256,
) -> bool {
    let total_sum = round_univariate[0].addmod(round_univariate[1]);
    total_sum == round_target
}

pub fn verify_sumcheck(
    proof: Proof,
    transcript: Transcript,
) -> bool {
    let mut round_target = 0u256;
    let mut pow_partial_evaluation = 1u256;

    let mut round = 0;
    while round.as_u256() < LOG_N {
        let round_univariate = proof.sumcheck_univariates[round];

        let valid = check_sum(round_univariate, round_target);
        if !valid {
            panic VerifierErrors::SumcheckFailed;
        }

        let round_challenge = transcript.sumcheck_u_challenges[round];

        // Update the round target for the next round
        round_target = compute_next_target_sum(round_univariate, round_challenge);

        pow_partial_evaluation = partially_evaluate_pow(
            transcript.gate_challenges[round],
            pow_partial_evaluation,
            round_challenge
        );

        round += 1;
    }

    // Last round
    let grand_honk_relation_sum = accumulate_relation_evaluations(
        proof.sumcheck_evaluations,
        transcript.relation_parameters,
        transcript.alphas,
        pow_partial_evaluation
    );

    grand_honk_relation_sum == round_target
}

// 28 = CONST_PROOF_SIZE_LOG_N
pub fn compute_squares(r: u256) -> [u256; 28] {
    let mut squares: [u256; 28] = [0u256; 28];
    squares[0] = r;

    let mut i = 1;
    while i < CONST_PROOF_SIZE_LOG_N {
        squares[i] = squares[i - 1].mulmod(squares[i - 1]);
        i += 1;
    }

    squares
}

// 28 = CONST_PROOF_SIZE_LOG_N
pub fn compute_fold_pos_evaluations(
    sumcheck_u_challenges: [u256; 28],
    batched_eval_accumulator: u256,
    gemini_evaluations: [u256; 28],
    gemini_eval_challenge_powers: [u256; 28],
    log_size: u256
) -> [u256; 28] {
    let mut fold_pos_evaluations: [u256; 28] = [0; 28];
    let mut batched_eval_accumulator_updated = batched_eval_accumulator;
    let mut i = CONST_PROOF_SIZE_LOG_N;
    while i > 0 {
        let idx = i - 1;

        let challenge_power = gemini_eval_challenge_powers[idx];
        let u = sumcheck_u_challenges[idx];

        let term1 = challenge_power.mulmod(batched_eval_accumulator_updated).mulmod(2);
        let term2 = gemini_evaluations[idx].mulmod((challenge_power.mulmod(1u256.submod(u))).submod(u));

        let mut batched_eval_round_acc = term1.submod(term2);

        let denom = challenge_power.mulmod((1u256.submod(u))).addmod(u);
        let denom_inv = inverse(denom);

        batched_eval_round_acc = batched_eval_round_acc.mulmod(denom_inv);

        if (i.as_u256() <= log_size) {
            batched_eval_accumulator_updated = batched_eval_round_acc;
            fold_pos_evaluations[idx] = batched_eval_round_acc;
        }

        i -= 1;
    }

    fold_pos_evaluations
}

pub fn pairing(
    P_0: G1Point,
    P_1: G1Point,
) -> bool {
      // Serialize inputs for EPAR
      let mut pairing_input: [u256; 12] = [0; 12];

      // Pairing input: P_0(already negated), [1]_2
      pairing_input[0] = P_0.x;
      pairing_input[1] = P_0.y;
      // g2: [[x1, x0], [y1, y0]]
      pairing_input[3] = G2x1;
      pairing_input[2] = G2x2;
      pairing_input[5] = G2y1;
      pairing_input[4] = G2y2;

      // Pairing input: P_1, X2
      pairing_input[6] = P_1.x;
      pairing_input[7] = P_1.y;
      // g2: [[x1, x0], [y1, y0]]
      pairing_input[9] = X2x1;
      pairing_input[8] = X2x2;
      pairing_input[11] = X2y1;
      pairing_input[10] = X2y2;

      // Perform pairing check
      let curve_id: u32 = 0;
      let groups_of_points: u32 = 2;
      
      let result: u32 = asm(rA, rB: curve_id, rC: groups_of_points, rD: pairing_input) {
          epar rA rB rC rD;
          rA: u32
      };
      
      result != 0
}

pub fn verify_shplemini(proof: Proof, vk: VerificationKey, tp: Transcript) -> bool {
    // - Compute vector (r, r², ... , r²⁽ⁿ⁻¹⁾), where n = log_circuit_size
    // 28 = CONST_PROOF_SIZE_LOG_N
    let powers_of_evaluation_challenge: [u256; 28] = compute_squares(tp.gemini_r);
    // Arrays hold values that will be linearly combined for the gemini and shplonk batch openings
    let mut scalars: [u256; 70] = [0u256; 70]; // 70 = 40 + 28 + 2 = NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N + 2
    let mut commitments: [G1Point; 70] = [G1Point { x: 0u256, y: 0u256 }; 70]; // 70 = NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N + 2

    let pos_inverted_denominator: u256 = inverse(tp.shplonk_z.submod(powers_of_evaluation_challenge[0]));
    let neg_inverted_denominator: u256 = inverse(tp.shplonk_z.addmod(powers_of_evaluation_challenge[0]));

    let unshifted_scalar: u256 = pos_inverted_denominator.addmod(tp.shplonk_nu.mulmod(neg_inverted_denominator));
    let shifted_scalar: u256 = inverse(tp.gemini_r).mulmod(
        pos_inverted_denominator.submod(tp.shplonk_nu.mulmod(neg_inverted_denominator))
    );

    scalars[0] = 1u256;
    commitments[0] = convert_proof_point(proof.shplonk_q);

    let mut batching_challenge: u256 = 1u256;
    let mut batched_evaluation: u256 = 0u256;

    let mut i = 1;
    while i <= NUMBER_UNSHIFTED {
        scalars[i] = (0u256.submod(unshifted_scalar)).mulmod(batching_challenge);
        batched_evaluation = batched_evaluation.addmod(proof.sumcheck_evaluations[i - 1].mulmod(batching_challenge));
        batching_challenge = batching_challenge.mulmod(tp.rho);
        i += 1;
    } 

    i = NUMBER_UNSHIFTED + 1;
    while i <= NUMBER_OF_ENTITIES {
        scalars[i] = (0u256.submod(shifted_scalar)).mulmod(batching_challenge);
        batched_evaluation = batched_evaluation.addmod(proof.sumcheck_evaluations[i-1].mulmod(batching_challenge));
        batching_challenge = batching_challenge.mulmod(tp.rho);
        i += 1;
    }

    commitments[1] = vk.qm;
    commitments[2] = vk.qc;
    commitments[3] = vk.ql;
    commitments[4] = vk.qr;
    commitments[5] = vk.qo;
    commitments[6] = vk.q4;
    commitments[7] = vk.q_lookup;
    commitments[8] = vk.q_arith;
    commitments[9] = vk.q_delta_range;
    commitments[10] = vk.q_elliptic;
    commitments[11] = vk.q_aux;
    commitments[12] = vk.q_poseidon2_external;
    commitments[13] = vk.q_poseidon2_internal;
    commitments[14] = vk.s1;
    commitments[15] = vk.s2;
    commitments[16] = vk.s3;
    commitments[17] = vk.s4;
    commitments[18] = vk.id1;
    commitments[19] = vk.id2;
    commitments[20] = vk.id3;
    commitments[21] = vk.id4;
    commitments[22] = vk.t1;
    commitments[23] = vk.t2;
    commitments[24] = vk.t3;
    commitments[25] = vk.t4;
    commitments[26] = vk.lagrange_first;
    commitments[27] = vk.lagrange_last;
    // Accumulate proof points
    commitments[28] = convert_proof_point(proof.w1);
    commitments[29] = convert_proof_point(proof.w2);
    commitments[30] = convert_proof_point(proof.w3);
    commitments[31] = convert_proof_point(proof.w4);
    commitments[32] = convert_proof_point(proof.z_perm);
    commitments[33] = convert_proof_point(proof.lookup_inverses);
    commitments[34] = convert_proof_point(proof.lookup_read_counts);
    commitments[35] = convert_proof_point(proof.lookup_read_tags);
    // to be Shifted
    commitments[36] = convert_proof_point(proof.w1);
    commitments[37] = convert_proof_point(proof.w2);
    commitments[38] = convert_proof_point(proof.w3);
    commitments[39] = convert_proof_point(proof.w4);
    commitments[40] = convert_proof_point(proof.z_perm);
    // Add contributions from A₀(r) and A₀(-r) to constant_term_accumulator:
    // Compute the evaluations A_l(r^{2^l}) for l = 0, ..., logN - 1
    // 28 = CONST_PROOF_SIZE_LOG_N
    let fold_pos_evaluations: [u256; 28] = compute_fold_pos_evaluations(
        tp.sumcheck_u_challenges,
        batched_evaluation,
        proof.gemini_a_evaluations,
        powers_of_evaluation_challenge,
        LOG_N
    );

    // Compute the Shplonk constant term contributions from A₀(±r)
    let mut constant_term_accumulator: u256 = fold_pos_evaluations[0].mulmod(pos_inverted_denominator);
    constant_term_accumulator = constant_term_accumulator.addmod(
        proof.gemini_a_evaluations[0].mulmod(tp.shplonk_nu).mulmod(neg_inverted_denominator)
    );
    batching_challenge = tp.shplonk_nu.mulmod(tp.shplonk_nu);

    // Compute Shplonk constant term contributions from Aₗ(±r^{2ˡ}) for l = 1, ..., m-1;
    // Compute scalar multipliers for each fold commitment
    let mut scaling_factor_pos: u256 = 0u256;
    let mut scaling_factor_neg: u256 = 0u256;
    i = 0;
    while i < CONST_PROOF_SIZE_LOG_N - 1 {
        let dummy_round = i.as_u256() >= (LOG_N - 1);
        if !dummy_round {
            // Update inverted denominators
            let pos_inverted_denominator = inverse(tp.shplonk_z.submod(powers_of_evaluation_challenge[i + 1]));
            let neg_inverted_denominator = inverse(tp.shplonk_z.addmod(powers_of_evaluation_challenge[i + 1]));

            // Compute the scalar multipliers for Aₗ(± r^{2ˡ}) and [Aₗ]
            scaling_factor_pos = batching_challenge.mulmod(pos_inverted_denominator);
            scaling_factor_neg = batching_challenge.mulmod(tp.shplonk_nu).mulmod(neg_inverted_denominator);
            // [Aₗ] is multiplied by -v^{2l}/(z-r^{2^l}) - v^{2l+1} /(z+ r^{2^l})
            scalars[NUMBER_OF_ENTITIES + 1 + i] = (0u256.submod(scaling_factor_neg)).addmod(0u256.submod(scaling_factor_pos));

            // Accumulate the const term contribution given by
            // v^{2l} * Aₗ(r^{2ˡ}) /(z-r^{2^l}) + v^{2l+1} * Aₗ(-r^{2ˡ}) /(z+ r^{2^l})
            let mut accum_contribution = scaling_factor_neg.mulmod(proof.gemini_a_evaluations[i + 1]);
            accum_contribution = accum_contribution.addmod(scaling_factor_pos.mulmod(fold_pos_evaluations[i + 1]));
            constant_term_accumulator = constant_term_accumulator.addmod(accum_contribution);
            // Update the running power of v
            batching_challenge = batching_challenge.mulmod(tp.shplonk_nu).mulmod(tp.shplonk_nu);
        }
        // NUMBER_OF_ENTITIES
        commitments[NUMBER_OF_ENTITIES + 1 + i] = convert_proof_point(proof.gemini_fold_comms[i]);
        i += 1;
    }
    // Finalise the batch opening claim
    // NUMBER_OF_ENTITIES+CONST_PROOF_SIZE_LOG_N
    commitments[NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N] = G1Point { x: 1u256, y: 2u256 };
    scalars[NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N] = constant_term_accumulator;
    
    let quotient_commitment: G1Point = convert_proof_point(proof.kzg_quotient);
    // NUMBER_OF_ENTITIES+CONST_PROOF_SIZE_LOG_N+1
    commitments[NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N + 1] = quotient_commitment;
    scalars[NUMBER_OF_ENTITIES + CONST_PROOF_SIZE_LOG_N + 1] = tp.shplonk_z; // evaluation challenge

    let p_0: G1Point = batch_mul(commitments, scalars);
    // Use the EC group order, F_q, to negate
    let neg_y: u256 = Q.submod(quotient_commitment.y);
    let p_1 = G1Point {
        x: quotient_commitment.x,
        y: neg_y
    };
    pairing(p_0, p_1)
}

// 1 = PUB_INPUTS_SIZE
pub fn verify(p: Proof, vk: VerificationKey, public_inputs: [u256; 1]) -> bool {
    let expected_pub_inputs: u64 = NUMBER_OF_PUBLIC_INPUTS - PAIRING_POINTS_SIZE;
    if expected_pub_inputs != 1u64 {
        panic VerifierErrors::PublicInputsLengthWrong;
    }

    // Generate the fiat shamir challenges for the whole protocol
    // TODO(https://github.com/AztecProtocol/barretenberg/issues/1281): Add pubInputsOffset to VK or remove entirely.
    // Now pubInputsOffset is fixed to 1
    let mut t: Transcript = generate_transcript(p, public_inputs, vk.circuit_size, 1u256);

    // Derive public input delta
    // TODO(https://github.com/AztecProtocol/barretenberg/issues/1281): Add pubInputsOffset to VK or remove entirely.
    // Now pubInputsOffset is fixed to 1
    t.relation_parameters.public_inputs_delta = compute_public_input_delta(
        public_inputs,
        p.pairing_point_object,
        t.relation_parameters.beta,
        t.relation_parameters.gamma,
        1u256, // pubInputsOffset
    );

    // Sumcheck
    let sumcheck_verified: bool = verify_sumcheck(p, t);
    if !sumcheck_verified {
        panic VerifierErrors::SumcheckFailed;
    }

    let shplemini_verified: bool = verify_shplemini(p, vk, t);
    if !shplemini_verified {
        panic VerifierErrors::ShpleminiFailed;
    }

    sumcheck_verified && shplemini_verified
}

pub fn get_test_proof() -> Proof {
    let pairing_point_object: [u256; 16] = [ 0x0000000000000000000000000000000000000000000000042ab5d6d1986846cfu256, 0x00000000000000000000000000000000000000000000000b75c020998797da78u256, 0x0000000000000000000000000000000000000000000000005a107acb64952ecau256, 0x000000000000000000000000000000000000000000000000000031e97a575e9du256, 0x00000000000000000000000000000000000000000000000b5666547acf8bd5a4u256, 0x00000000000000000000000000000000000000000000000c410db10a01750aebu256, 0x00000000000000000000000000000000000000000000000d722669117f9758a4u256, 0x000000000000000000000000000000000000000000000000000178cbf4206471u256, 0x000000000000000000000000000000000000000000000000e91b8a11e7842c38u256, 0x000000000000000000000000000000000000000000000007fd51009034b3357fu256, 0x000000000000000000000000000000000000000000000009889939f81e9c7402u256, 0x0000000000000000000000000000000000000000000000000000f94656a2ca48u256, 0x000000000000000000000000000000000000000000000006fb128b46c1ddb67fu256, 0x0000000000000000000000000000000000000000000000093fe27776f50224bdu256, 0x000000000000000000000000000000000000000000000004a0c80c0da527a081u256, 0x0000000000000000000000000000000000000000000000000001b52c2020d746u256 ];
    
    let w1: G1ProofPoint = G1ProofPoint {
        x: [ 0x00000000000000000000000000000010fa7b1aaa9ba9e442fa0051560b508e30u256, 0x0000000000000000000000000000000000216aae52e33f921fa4cc40e8b9943eu256 ],
        y: [ 0x000000000000000000000000000000028a48f8a78b540580fbdbda9476ffde9au256, 0x000000000000000000000000000000000026b4e8328f49335d5205e5b0c999ecu256 ],
    };
        let w2: G1ProofPoint = G1ProofPoint {
        x: [ 0x00000000000000000000000000000065d7013c836a972c78cf3e459c6cc8b7afu256, 0x000000000000000000000000000000000015dd4333ffac89279ea5b471721445u256 ],
        y: [ 0x000000000000000000000000000000f3bdb6623f462f576d8e2e73aadd1fd417u256, 0x00000000000000000000000000000000001b95b7daa331040370ba43807100b9u256 ],
    };
        let w3: G1ProofPoint = G1ProofPoint {
        x: [ 0x0000000000000000000000000000006843a804e9bf0e8f767cc6bb12f5e13075u256, 0x0000000000000000000000000000000000061afaa692de83141d892d1efd64d9u256 ],
        y: [ 0x000000000000000000000000000000a13f5266217556205ea4d6c8b47d53c391u256, 0x0000000000000000000000000000000000275db0609534ae55f9b23344b524bau256 ],
    };
        let w4: G1ProofPoint = G1ProofPoint {
    x: [ 0x0000000000000000000000000000006deb86faee08f2d9680caf3542b197d20fu256, 0x000000000000000000000000000000000022a547dbb6a9886fdaa82333e03f3cu256 ],
    y: [ 0x000000000000000000000000000000cf9240a6ea30fd0398c23dd348782350b8u256, 0x000000000000000000000000000000000022fc6a56e74b53d720a86e04137880u256 ],
};
    let z_perm: G1ProofPoint = G1ProofPoint {
    x: [ 0x000000000000000000000000000000559ae14247c89864af88344a4869f15bd3u256, 0x0000000000000000000000000000000000189076afb485f2e0ff56f4b850a18fu256 ],
    y: [ 0x0000000000000000000000000000004d8fa984518b1bd68e8a24224018eb3bbbu256, 0x00000000000000000000000000000000002017c12d5fa1cd32b84edf26bc6fa9u256 ],
};
    let lookup_read_counts: G1ProofPoint = G1ProofPoint {
    x: [ 0x00000000000000000000000000000079cf93b804469cfd1aed183baaeae73de8u256, 0x00000000000000000000000000000000000e59187557f6855bde567cb35ede86u256 ],
    y: [ 0x0000000000000000000000000000008bd253f9ec6d2aa0aa50326c8365f4771fu256, 0x0000000000000000000000000000000000094ed7be0bdab40ba71f0b5a713f46u256 ],
};
    let lookup_read_tags: G1ProofPoint = G1ProofPoint {
    x: [ 0x00000000000000000000000000000079cf93b804469cfd1aed183baaeae73de8u256, 0x00000000000000000000000000000000000e59187557f6855bde567cb35ede86u256 ],
    y: [ 0x0000000000000000000000000000008bd253f9ec6d2aa0aa50326c8365f4771fu256, 0x0000000000000000000000000000000000094ed7be0bdab40ba71f0b5a713f46u256 ],
};
    let lookup_inverses: G1ProofPoint = G1ProofPoint {
    x: [ 0x000000000000000000000000000000dd8f60a543de4ef66c6b4d69d96e0648f9u256, 0x000000000000000000000000000000000014b07b95b023be7035af60110f8a24u256 ],
    y: [ 0x0000000000000000000000000000000a9fe472ed3a88bb8566e5e9c13714de5fu256, 0x000000000000000000000000000000000018c8b09b1370ae2c5d0ae8c84c0432u256 ],
};

  let sumcheck_univariates: [[u256; 8]; 28] =
        [
    [ 0x260bb8f4003f6f97f12667799af770d7f55ab6db291142b739644e2416a60ed5u256, 0x0a58957ee0f23091c729de3ce689e78532d9316d50a82dda0a7da76fd959f12cu256, 0x16a94abfde149ae21d5ebac7e6cad578bb3567ed577ed1cbb7fb654ed235667cu256, 0x20d500a2f84754b9297994aa5d4a2b6c051e26660e0edc33cd5f1dd8ea6c29e8u256, 0x2624113eb35b76553dab8a3240b6781289fcd943fb047057814374e561f4dbb5u256, 0x11985551a82dd45248488195db95161301d5f944e8b7c8d325da02128eeb5941u256, 0x26537cbf7d46ab78ab355367943d5514fbb6fb217ef138a6a7c9f5fab44748fbu256, 0x2a3062907a4d6c6a37fb25324f092a3f40aab01c27b925e8749be6ce8fe6da52u256 ],
    [ 0x0a25f36503f1fa16cfdb454553f9ba8c9140b45c5b4bdb2349ee2a36b25cbcbdu256, 0x2e920815c3aa6d4b5851c1b7a13cbf9a33329636f204cbc3e6ee8ce02ece283cu256, 0x26738dada9317c48a4f9c364fbd9a235b98f223241835290b3df85731111804bu256, 0x013b71ac86895053e00f63a0473107bce8c6b65fb090eb7f8c30990fd3f50783u256, 0x0ddb2cee961c042ef21cda9a82469842bde5d6512051845394e231ad5dda902eu256, 0x0361012c6fbddea4febc1360c0d73fd1a53471e563f9c2be70e63c7ef4b705ebu256, 0x157b553fe7590bbc256297d1326365b22160c9cc32874df9edf18134cff187cau256, 0x2d0d0f343d62514a1ff262451912326ebf27cc180ffe5080dc168288882212ccu256 ],
    [ 0x20ba21ea1866163ade8444be309a513c27bbdeffdce4113e0da72f80741fc842u256, 0x20923a6e866e4994117cf67cf244b4ebb3d801bfb6cea6c2064b889ab5dda7eau256, 0x1e9db3c08581d5da6ccca4653a502809ef5c68f1901eca4557349bc293b539cbu256, 0x28f55a3805a5c5a5d5904f7faeab75e577f16de092550c2b38a961c2e64a2315u256, 0x1b2cc426a814a170bdb94713f41d2f8a9f331e9fecbe849d95d66754d97f98d9u256, 0x2c61af8749b555ab517bc222c8e3e29bc3fc8ff2637d43f681bb4f12ed513ff1u256, 0x1ff7de8a51b38a7afd5b794dd18a01870388a465ba88aadfa5103103752c207cu256, 0x22f9570d191c30b394070e3856da2dec98b2ec8845f369a406e5c6cc636b23b4u256 ],
    [ 0x0bd5d3e5e8801da0f70e4097c7b85a3ce94adb59e4b7fd8dbf676e8ed794ea8fu256, 0x1fa9d05616d08b929fec038819fe06c95b55d46f29d8de46d26a5448691feaa7u256, 0x24eeb7cb5eed939012240e2828ae341504cb778cccceba66ec0323b5c3c1e253u256, 0x18fcc1eb7c3441c170e2de933912aa627a48dbbd5f282eee6ca46e6804635323u256, 0x0681b2037f245a5220a2d503a1f267a2dd278d0ca51a5d93e7304327652e2d20u256, 0x027240c7aba9c0484956e0e06847342163b7fb1838fef7af927a9bad0536955cu256, 0x0cc7b533c45b042a58df7c2f32b4585b3d3f0ce62b0938b9eee545433bb36e0au256, 0x13479e3aff96636abd7cfbc37e4096cfa8bc147a75d46e9bfe7672188d74a9bfu256 ],
    [ 0x0ec65611733287edb4de4202b6b9fb8ce9b0a77cb99ac49c2b52f8adbad95d9eu256, 0x1e223c7d0097e667356298da7b96f10ca5b8eaa008e99e13ed4dfc3cb35fb639u256, 0x279d478277514f9f7439da57d14a5f6643cb8e113e6c1f96afd8d61c8fe3b79cu256, 0x0953595fdb2799218fb02610a98e854a2f414aa5970001140ae01ed935173134u256, 0x2994d016e259d87adec985e50a5869944722974c9ad29b4bc4dad9a03a331639u256, 0x223ca81de20f0d447df78b9a37a82119c4dbd270c096caf3318e5689a758683au256, 0x052297133ee2ec266114e6a0bd45e676ba0889e2895c9cc7ea6b1de97419461au256, 0x217c83b0af34dedfda8bbf4c1735a4236d26c220269be2bd8392a668dc779b0au256 ],
    [ 0x2e2c6b1cc47cc253ff890702865889e9e2eb5e3d7307d192a2438d60148fc612u256, 0x2e97d2e3075ee38637bf4cdbbcfe81e1719eceda8bce0cf7fd445788ba0b055eu256, 0x039af04771eb4b5c7421201965040af81a8966c62c4516a035a51bf49e492077u256, 0x0aed2c424dc0b4c312b84d51a4d1fd526f7955b8df0715867c55f05a6eb6a205u256, 0x1a21e7b2efa629d24ee16deef92f096032f12d7ec0e5152254644530e06507cdu256, 0x10b6adf3bf39f6075fb0aaa0ac967798a55d2db26e69281f80c5a86e8c003d60u256, 0x163e98182fb7556c94df429a2519e27e17bc046952c803b2d49bc9e400d665bcu256, 0x12e2a7865e3dabba862ad3067e77ef07db6712cb43bc6fd69922a5f299d3f211u256 ],
    [ 0x10980a780aec19eb6e34c59fd41490cf54eabaf6348f4264ca4fc03995e0e058u256, 0x09c5668001dbd12edf2bd7b0e903b3ed68f6b4adf2b25ec4915369784a295a0du256, 0x28d75b86087b1ec7c7254d30ad3de687c53f00d99764186d602a91432e2d425eu256, 0x1a51fa5741dd76e8de5510a69b19b87163ce81033bef4fb55dc2517e20f5ee12u256, 0x28917c790696149a42f3b06f2af9d68cece62503fadca9d957aef133ce154619u256, 0x2f1766baa6c847b5eaa33310ac6e12c294e633cd269649bde04fe44023dc9502u256, 0x1de6f8114d8dddf32a4f674c744376a8c2c959822c7e8109c97e8a50de1e92fdu256, 0x28798118177b76dd826e95b39873c924ce24aa8346f672f06a73c39eedc504efu256 ],
    [ 0x2d57ef0bf013d7de4c6c20a01936f8a3b5bfe93906690c1fac3c09eeb22dd59du256, 0x2fb0ef44fcf3c4189ea5931ef966879fdb968d1a615acea359f7f35608e8c08cu256, 0x0d44b73d3595bada2488f4c3f345f15f00c6a52d1e943ed6291ba5ff14e984acu256, 0x0d9021025252614e70a01089de255084a99b965e28c93c7ca6fdcd869940b72au256, 0x23ea752e8985d8dca138b62da2bca21e62635badf14eefdb85830b4fe256efbbu256, 0x1ba5ffdb5c88da74342e5f76aa7dd19787b1dec4ade768f9f5ee62b1536e9581u256, 0x093ef9ff7f8c55d19fad72b66328c9688a5cf32395361590e4a4e4cc0546dfa2u256, 0x2440814eedfd6c04baaf5cba7e368f1d534b5e4a3590a71cdcd9a7f784e3c98bu256 ],
    [ 0x23107c849b7e88ff469053f3152b09b32e03e65575a04822829ae84d3d1859ceu256, 0x0ebfb25242b5a403edaf6db24f8eb29d2989d55c8cfdfd8f32a8981e6f86c110u256, 0x04da10fb167ad554d74bf9a016573d0a3f47c26b1d7e09802a2e227edbf24ee1u256, 0x04316cef4357c7250e7e3009ed4780feb770d4aa8e0add8c9f3e6ee6e6e4b929u256, 0x1b65815ba74eed3eb6f3fd37810d267e97c1b101cbe8c9274fbecb3dac0b0430u256, 0x293170c3526bccb38f81b590425a61c0884d9a32862b287830d7bf210d1711a3u256, 0x0f19658b0305d265813257506957a97ad3b67cf29ecd286b164ada9a4df1bb36u256, 0x0a160b8e39ae432db8b653720ddd0e21884c5f2ddf3174fb7d223d5d61833d3bu256 ],
    [ 0x035a2557d828c96fa394773d861eb9d7ae0190d2f56045afb9329c1f5863a617u256, 0x1f999cd626daafe0b451217e958f3a6f7ee6ba3d65faee712841805f67edc6e8u256, 0x1ec492b234a35a9894650d7af945ddf13cb4c58d900ce7ebca18e26ae97401abu256, 0x0376f925724d8db3bc2610c7171852b934ce13682af4a060ae952d9882aeea4du256, 0x1a820166be33eb39a7f65440933624b6adf436dead98801094bf25b05a09a573u256, 0x29964d4c8a9600d0c48f6f8c1424e79b5d1b19846c4a1ed71af414bde10ebbacu256, 0x252453a7bc42fe15b7721d355fd9e227516ebec9210b8794d144d5c709aa1cb1u256, 0x1fec293a175db1fa5b7c4528dd78281bc2854b4e3e34ed4e2c6e48ca45b5e634u256 ],
    [ 0x2ac952f67136d23ca544cd4fe72ade02e6b1dceaf4027cc0ec814412cfc41978u256, 0x14ce68ff49df6a03786ecdd83e1dc7e29fee7a46d57a19b43d567397a5250ae9u256, 0x154e59c72d259eb069316e32fc88fb03ab8d412058eada7199af89bfeb677e20u256, 0x007f864ebe63fc8aece0894e4675b648cacec91222f350680976509b220aae05u256, 0x203e3f2348f06096cefd48ba7993d49aaf8ecf10dbfabd34cdf69ef36ccadeb6u256, 0x29ff770c0609c7138d0df29d32c89a73ddb76120a6ad10652469330c51423745u256, 0x1c3bf2387eaa005854d9f13e0dda6437eff9be803daf0d44d81dd5dadc73d20du256, 0x0273a7b720c8afb4faa66c484657acba465fd5121fc471e7bb5a39a1e25a5d4bu256 ],
    [ 0x18f773d5b108b4280b6af4d3078e76957cdfbed7957dc89e2b59350ae6bee6dcu256, 0x21f7ed83cc3054a627dec18b19c7efe390b4e509dc90151c908456ae0588eb59u256, 0x23b41adf713663dc1daf058a1fa17b3624d2b7b440aba72561449d678cd5fafbu256, 0x108b2ace48dac59ae3fac24210ef762e5bfbbe772c2e5c53abe3d2342aa1b962u256, 0x1e79dd87e68c07cf185f38c7df86e8c62979e95914a3b3128a1e6d7acb259210u256, 0x18d4cc10f810e77069e8f940a068c1773bfc8a3d1fdafe9c054aac33621b64c0u256, 0x301d0ccaeff33ef34fd43e0ac98ed13a2f379415366eb6bda01408156e8aa049u256, 0x0d25dfff672ca5eacc74041b3f4c80d57443e59328fbbe23dcce126437e962bbu256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    [ 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ]
  ];

    let sumcheck_evaluations: [u256; 40] =
        [ 0x1908b4f0fd5838e75a6f6031b78e394cd5df3f25feae2611664535f7a9593873u256, 0x21a0fa8ffa710fd2122dff3ab11fe360f03a42e8ae868de9179388ebeed27608u256, 0x0bae9c9b2791fdff20ade77e29f01ed7e17a1de395902d9108de401204e6428fu256, 0x05abe98b0dfa1bdc1ee904b940495e44cc560a2b08119748c15a770ec6d41015u256, 0x0993407c8ef91bf2600d06653600ba42952631514d959fd009b28aeac09b3e78u256, 0x185a92767c3be7a7160db52234bc880133ebb7c0282e35084e968b3c2508d466u256, 0x266191706a86a6ccd226ef02f14910f716b6ee8288c4b741ae977957d2e2b82fu256, 0x1a9c9fadb2557101a8c4d0a699852f39eab0234d1188993d1e57e4c1ea4e730fu256, 0x2263056b56be51634b65de6300c52df703608d3b47e586123adc810504dd519au256, 0x23e7bad63b14c8f20c973bd16ca6d835563c3c1e0a2066add056459deaded9eeu256, 0x1d425ebe0fc532f32aec50132f1e736c54d028bd09d9224d80cb64c207265efcu256, 0x2b31b1414202bb3dad1f0befbb5f83a7bb73b22f12af1c3cc94b623a4b86de7eu256, 0x1ef9483dcfdc589755ea2a3b1232793cde4dd7d3e32643dde7a94d1deb417f6fu256, 0x0fc0ecebb1c997b089e1a0249d6e41c566071be1a74d71d69da26beaf0558ce3u256, 0x163efee69542cf4e126ad49d94fd5ef703ea91f34043cd3da68d3fff2e268e3cu256, 0x13bbd286a6e1548386cbc3ed289a40a4f3cc8bd670e415966957988c50c73357u256, 0x0ff89b27e1d5c1013549995ac7dee5be83fd2790c337371dd828f04bd80fd3fbu256, 0x1d9c377ff09ac97ff416fd35c86de6217391465af63d93bee8e10bef9ace864fu256, 0x300158607bf7a4082c9f21d608282e32656c1c05b0a31613344013b5a5e6e34au256, 0x1499627e998ae57d826e14d967f56a3674c8af05c40ede980b4807bc214b3d45u256, 0x03214de07b1fa23c70297d72106fb1a418967e2f71519c3e742a05d133c28bccu256, 0x16f4e326933d6a469b0998406710a75e20172e736ecc8297fb0463ca95eb1ae5u256, 0x14f35965451c9fe117de0deabfcc98d6451065cb14eaff3e72b6f24ac3917a05u256, 0x1a451a098b96462f3e53bf4ee10157b9f9ae14bbb27fe4b31da8f0e4259e8462u256, 0x144ad82c74dc4ea98a42133cf4678f38d94a0e4a70f75065c2b56bcb43313b73u256, 0x066c40548de9377672230ce79ccf4e27537157bc502a94f96e682b60d2fbcb48u256, 0x06cbe913f3a52fa77e82c986098af0b082b552f3b60e426f289304a93b99a35du256, 0x0fc9243250187f8184c4c8ebd5251b7c7abdb3e7229e310baf376d89249324d9u256, 0x0f9a67ab3e7b26a1af5caf733683c784802af5e19dd105944d27f13a6553090fu256, 0x0f0830f52c2b009c475704e3e336c9f49aac032fdd65da1aa385d1b77c2988a5u256, 0x13ec87245374c9e52bfa0c79414e8e4e8bcf36c7c19cad47c490de0c336500eeu256, 0x0fc30301c37920d58670295a41fcf8501ea419cbc7e3e49a2d17781267f1362fu256, 0x1d1ee95282e3401da7fcfe68a93ee6545cedf51688193a88ba7212a7f6e57ee2u256, 0x2ac55ff727daf86ddff790ba12108055102c8370a866b287084c199d9fbdf0cdu256, 0x2ac55ff727daf86ddff790ba12108055102c8370a866b287084c199d9fbdf0cdu256, 0x157692e936821c9f38d040900db1b3cfca67348d5ac049eb12d0d057251a274du256, 0x17e998d7ac562c8326acb778aa50e14e2e160d070dd467d4989039724e430871u256, 0x19a5f0ba89bdfbb45edd98d94d2507933c0ad74ab2ac7f71169ed74afa34c96bu256, 0x1a1c9a4dec47774affa5d8defc568bb1f99fc9a02d5db9837637e772ea092ee4u256, 0x266efd925701524f5b2502208bc271c1a4cbd466cb3d7c785b41a69ff0251374u256 ];

    let gemini_fold_comms: [G1ProofPoint; 27] =
        [
    G1ProofPoint {
        x: [ 0x000000000000000000000000000000c9636e024e3bf3a50b59a36ad15e7e11bdu256, 0x000000000000000000000000000000000026a5e10d369eafa019e6cabc0022e6u256 ],
        y: [ 0x0000000000000000000000000000008e4cdaec80ca33ef997fd31db94c322b91u256, 0x00000000000000000000000000000000000c0813bf8d75bd27a2a04984274923u256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000324b4235b8359f09020151aaf84b1d3d50u256, 0x0000000000000000000000000000000000185fa584995604beefd87ad7947ab0u256 ],
        y: [ 0x00000000000000000000000000000029028b5f84fb0cfa8c5f3b2377cb888dc2u256, 0x0000000000000000000000000000000000178e4e61ef8cc5e7c0d332929aefadu256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000f82a4f6e51c28bc5f1f685423eddd8e927u256, 0x00000000000000000000000000000000001321e2061ffdbfbaeda33852d6dcc9u256 ],
        y: [ 0x000000000000000000000000000000fbd791e059bd752678d3fe1b199d5a9dfcu256, 0x000000000000000000000000000000000024a017977b7ce22819d2c44bca8bebu256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000fb737a370b111dd3dcaad3770ad28f3fcau256, 0x000000000000000000000000000000000022195c0d83a514e07bb7b4fd32048cu256 ],
        y: [ 0x000000000000000000000000000000db89941347bd373fd70cd22699e62cede4u256, 0x00000000000000000000000000000000000971c570c6fa973cd583c94b97937au256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000f7344c11778cce4733c7133b0dce35bb7u256, 0x0000000000000000000000000000000000054a36c48208ce3a2d20d6acc3e8ecu256 ],
        y: [ 0x000000000000000000000000000000f4cc1aa0c928f29aa6f948f02397f2ad4fu256, 0x00000000000000000000000000000000001b562172a4a3a830d9d3eaa694aad4u256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000d8c3353eb3a7583d623927591b72907a90u256, 0x00000000000000000000000000000000000af7aed738f1be37f22286c603882eu256 ],
        y: [ 0x000000000000000000000000000000bc7a4ee9a9aa0ca83bcbba3d01ca63dd19u256, 0x0000000000000000000000000000000000251a5486591774d27d694b852f5fa6u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000002161cbe3f0a022cb08dc14c2be537b6822u256, 0x000000000000000000000000000000000021f90eb171890408d56a735f086d7du256 ],
        y: [ 0x0000000000000000000000000000009b1e2f1c05cd7f3c6a663185fa399b8048u256, 0x000000000000000000000000000000000017e1ccdacee73d037200a1146b1f41u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000009a3b411a63895e0e52e5f13b79f4fffd76u256, 0x00000000000000000000000000000000001f4b37f388f2c3d8436dbde74dbb24u256 ],
        y: [ 0x0000000000000000000000000000008330e2eb4d51baac1e6771a02a560d9ef0u256, 0x0000000000000000000000000000000000156cd1a230b5ec449dfea7d805cce3u256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000f044c1a4b41d23f2614d57178fb1e76ea6u256, 0x00000000000000000000000000000000001875268db4f0f091813ff2f78e129au256 ],
        y: [ 0x0000000000000000000000000000001a71daafd8e23061b2661e39d052a98698u256, 0x000000000000000000000000000000000005283736df754221c30710935ba400u256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000fe69f6128ecc109c8e1b0ba133b8954801u256, 0x00000000000000000000000000000000001d77b4711333258e36e8e65c4bceadu256 ],
        y: [ 0x0000000000000000000000000000000af73ab0f04bb3045762d690e0f0dbbaa8u256, 0x00000000000000000000000000000000000a6b126446e4a284ed1f217f0c5de8u256 ],
    },
        G1ProofPoint {
        x: [ 0x000000000000000000000000000000ba4d19ae66a813610e4de8fed4da9c01d2u256, 0x00000000000000000000000000000000001b7523faa123d51e35849cd0449748u256 ],
        y: [ 0x000000000000000000000000000000075ca3e91c48b0da35335ab1956cc96986u256, 0x00000000000000000000000000000000000b32fc701bd6666d33ce159cf64478u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    },
        G1ProofPoint {
        x: [ 0x0000000000000000000000000000000000000000000000000000000000000001u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
        y: [ 0x0000000000000000000000000000000000000000000000000000000000000002u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ],
    }
    ];

        let gemini_a_evaluations: [u256; 28] =
            [ 0x0ebc89b76c8a449cfea7e736614b7341c5d631f5cfe5e719eb4d59de84a17023u256, 0x00ca05a8258855cc5f308d73b5ee7190ebb5182ebd2ac6aeb498792d6613ea4du256, 0x2396e0e54a12aab2cf38ca92e3acf76c84d98d8b7abd2392f81d658fb929b43au256, 0x0214bbe94bf9fbcf5791b5e4c81b956c934abfa8d695f4e1bf6c752d2b291fe6u256, 0x0497fc38d8f711c251034636f54eacf286fc0ddca723528a00d9fcf426bfe4f5u256, 0x08e0d3a6c8cae9395dc944a93253e74e59331519f0d39b29e7292abd0fe38503u256, 0x164100d98e7664dba57fabfb92d283dba5f61394e6de70204b7576679390b526u256, 0x0e808215d3b9b839a5b965b256b9891d824dd314da677d6421323efbb5f7ac8du256, 0x2606a656d161c747ea6b77d374cbd4fc8ec450bc0392eb98f745cad028864ae8u256, 0x103b5ab1461622adcf42176aa688e3a65e7386a82be0db65f21cbf3a59d065acu256, 0x019642151cfc54486c1d8ef7f27bb04cc4a0cb77703ce1a54ca696953899839au256, 0x0b65b0477de5a7bbbd729aeac5303e59b1c14d1ffddd6a2298cdbf898cb63ceeu256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256, 0x0000000000000000000000000000000000000000000000000000000000000000u256 ];

        let shplonk_q: G1ProofPoint    = G1ProofPoint {
        x: [ 0x000000000000000000000000000000b6da75e4f8a81d317243720dad0ff1e989u256, 0x000000000000000000000000000000000013e7390783fe5af683f3fd42e36992u256 ],
        y: [ 0x000000000000000000000000000000958792b377742e6942a2ba2fc9a961b8d1u256, 0x00000000000000000000000000000000002f3e227b15a9ca9b70b6a2c258fd6cu256 ],
    };
        let kzg_quotient: G1ProofPoint = G1ProofPoint {
        x: [ 0x00000000000000000000000000000045286f9e17b38e4a4ff55257d4e0627024u256, 0x00000000000000000000000000000000002a2ca84bf520c438c87d8977ba182cu256 ],
        y: [ 0x0000000000000000000000000000003d302b8b91e25a995aebe9e7d391f6400du256, 0x0000000000000000000000000000000000118d8dea5ee091bfe7027b229cf25bu256 ],
    };

    Proof {
        pairing_point_object: pairing_point_object,
        w1: w1,
        w2: w2,
        w3: w3,
        w4: w4,
        z_perm: z_perm,
        lookup_read_counts: lookup_read_counts,
        lookup_read_tags: lookup_read_tags,
        lookup_inverses: lookup_inverses,
        sumcheck_univariates: sumcheck_univariates,
        sumcheck_evaluations: sumcheck_evaluations,
        gemini_fold_comms: gemini_fold_comms,
        gemini_a_evaluations: gemini_a_evaluations,
        shplonk_q: shplonk_q,
        kzg_quotient: kzg_quotient,
    }
}

pub fn get_test_vk() -> VerificationKey {
    VerificationKey {
        circuit_size: 0x1000u256,
        log_circuit_size: 0x0cu256,
        public_inputs_size: 0x11u256, // 17

        qm: G1Point {
            x: 0x1208635a7028956453296549241f9377f8581269d93b70bed2724e7b1c71dc9eu256,
            y: 0x116a3936704da2d485adce48c9563a7423322a73fd13d0c8f5887f0594c63669u256,
        },
        qc: G1Point {
            x: 0x252bc7ab5dc59f39b730bdcaeb4a336cbf94dd779bc4b3edd4f99e6277a23bf9u256,
            y: 0x2fd92796d0c8f00738a8bcb0511083d3b9f754615d12ef9b117d362ed1514229u256,
        },
        ql: G1Point {
            x: 0x1b24a873eaec2d6d976feb73deb29579373ee038e806f2ebdf5b682a9548487au256,
            y: 0x131a08adef827f7990cae77c932d2d61e4f5acb61ed6f0c30eefc8481c204e44u256,
        },
        qr: G1Point {
            x: 0x1ccef7fbb76e87a2717d70221351eb7091a9eb4402fa50f15ee390b3751e2e93u256,
            y: 0x00ca2851a7562bb9a19963c342f93afe33e5c485357265ae9de5f7485048373au256,
        },
        qo: G1Point {
            x: 0x0e2e489df6a14e3e1d1fc420297a9a2e04d0405335e1eb0144e574db9abc4dd8u256,
            y: 0x07d6bbcf4d83cff318665356dd825ff9fa5ea3ed6185476309f49adc5ec4d1ddu256,
        },
        q4: G1Point {
            x: 0x0961ae6f667d56daea8c9da340b077be6254f736693b3a159a0a882c32db15ffu256,
            y: 0x29b58b4d5e0a3574cf0ef17eb7738cc07a881aa2d7f4aa77d7c17ce521bfc74bu256,
        },
        q_lookup: G1Point {
            x: 0x0c4032c3079594eb75a8449d3d5ce8bc3661650d53f9b24d923d8f404cb0bbc9u256,
            y: 0x1084d709650356d40f0158fd6da81f54eb5fe796a0ca89441369b7c24301f851u256,
        },
        q_arith: G1Point {
            x: 0x0e710c3e8fa66750cb47ec8427fa2105de95d660cf1fad129af51a92cd641749u256,
            y: 0x24e8061804314ddca8bef04783e03d6cee8a8c30f65b0bdd6496e131ba203c55u256,
        },
        q_delta_range: G1Point {
            x: 0x090e7ca17bcf5837ee1263f7dd3353082fb32a2e75582f4a5be8cb04f3e17c42u256,
            y: 0x15c7401082cb5751fb8d55e633730d05b13e56c9318bb630111b7012e1a3070bu256,
        },
        q_elliptic: G1Point {
            x: 0x1e3f13af784074517f0b4daff7e128070df114a066da5cda519e3de92d102c02u256,
            y: 0x070ec8a6f972659c95f9f6600f092451524d74e86ab84104646771a6b85aa912u256,
        },
        q_aux: G1Point {
            x: 0x1471f91513ef2e4991c69c499c7a78a069ee12e07a42140c92f5eed93f6072a5u256,
            y: 0x0cec55d4f5912cc7c4820ff2751df0b4bc175d955a598cc16d91c97573d5e0c1u256,
        },
        q_poseidon2_external: G1Point {
            x: 0x071988d570486620d34ecbf237cd069e93eee795d69738ba349a6d8bcb53fbf6u256,
            y: 0x01a01ceb5d64a3bceeb5f681cf08383ea2410048ac3867ec7d7eb743a5ec57beu256,
        },
        q_poseidon2_internal: G1Point {
            x: 0x222a00990c265db917ccf6e4381cdea5d16200fda7af5265690cacda94ae7131u256,
            y: 0x198a29bf1f6391c8487a4423a79256ef4609b87d44bedb68d26a4d64700443eau256,
        },

        s1: G1Point {
            x: 0x287d13fcda26c48b0bb1f260d05037ffa2d5f9ff1d068bc22efbaa45b229d50eu256,
            y: 0x0216d8dfcaa6d5fd9e3b6b527db18f99fa635c24fe7a9392704d3b8f447a3a42u256,
        },
        s2: G1Point {
            x: 0x05094c543339481475617e900af3632408f65424e36a1e03cb833f43a245a1efu256,
            y: 0x2f7013922b53d3a24a6d479eb12718140f96d8b550b4864b8ef0dff1fdf20cdbu256,
        },
        s3: G1Point {
            x: 0x1025d8b978868db845221299b8fd932ca1774f435529ead61158296cfa47f25eu256,
            y: 0x0394e620db0b96d6527ac455ef5d3191737d891550ade79fc7d6728607444ef6u256,
        },
        s4: G1Point {
            x: 0x0090a5e98f0f54d821687048a0ed449c0416efafcd9f4da1adbb4eb263ea2065u256,
            y: 0x1aa3ca60381e96ae2c1261f990fb8c5ab72540ca6ebea80bf06f93f7a660a8eeu256,
        },

        t1: G1Point {
            x: 0x0450f8716810dff987300c3bc10a892b1c1c2637db3f8fecd9d8bb38442cc468u256,
            y: 0x10005567f9eb3d3a97098baa0d71c65db2bf83f8a194086a4cca39916b578fafu256,
        },
        t2: G1Point {
            x: 0x103bcf2cf468d53c71d57b5c0ab31231e12e1ce3a444583203ea04c16ec69eb2u256,
            y: 0x0c5d6e7a8b0b14d4ed8f51217ae8af4207277f4116e0af5a9268b38a5d34910bu256,
        },
        t3: G1Point {
            x: 0x187b9371870f579be414054241d418f5689db2f6cbfabe968378fd68e9b280c0u256,
            y: 0x0964ab30f99cb72cc59d0f621604926cfebfcff535f724f619bb0e7a4853dbdbu256,
        },
        t4: G1Point {
            x: 0x132b76a71278e567595f3aaf837a72eb0ab515191143e5a3c8bd587526486628u256,
            y: 0x2c6b2a0de0a3fefdfc4fb4f3b8381d2c37ccc495848c2887f98bfbaca776ca39u256,
        },

        id1: G1Point {
            x: 0x23bd8229bd24116d12ad49876e65f9bfeb812d393efb1aefcfbe475d43d16bceu256,
            y: 0x2ddbdeee1f588dc566403aa2b566c907bc733c7360efe1bbdb1c42e1f0807cfdu256,
        },
        id2: G1Point {
            x: 0x1941a2c0491d802736c28cb48429ab0b44258ffe607344a0b815b96b8f18ceaeu256,
            y: 0x1053ee3245f1c1dc917c1bdafde59a745a1cb149745a72bcf90ab320d206cec4u256,
        },
        id3: G1Point {
            x: 0x23d39513e543a380f5fc96d01584219044e6ec9883d4af802c5e3aa54c77894cu256,
            y: 0x1ceffe0e20bc00ac0ea67fd13e94ce243d8a3633339ce78c1394519a37719864u256,
        },
        id4: G1Point {
            x: 0x0a7bad3b189391c4d816d1176c8ad3752b86188edf751f6776b268e84f4f3768u256,
            y: 0x0892a913f320741d56d960d236fa73800a531e52650b6352c0deb1f7affd1d6du256,
        },

        lagrange_first: G1Point {
            x: 1u256,
            y: 2u256,
        },
        lagrange_last: G1Point {
            x: 0x1e05165b8e92a199adc11aafdf37b7fa23724206b82e0864add6d4d3ef15d891u256,
            y: 0x1490b97e14d7a87ab24c2506b31a5f1c19e519f9e46735398b7d7d3a6e8b6291u256,
        },
    }
}


#[test]
fn test_split_challenge() {
    // Case 1
    let input1: u256 = 0x11223344556677889900aabbccddeeff00112233445566778899aabbccddeeffu256;
    let (lo1, hi1) = split_challenge(input1);
    assert(lo1 == 0x00112233445566778899aabbccddeeffu256);
    assert(hi1 == 0x11223344556677889900aabbccddeeffu256);

    // Case 2
    let input2: u256 = 0u256;
    let (lo2, hi2) = split_challenge(input2);
    assert(lo2 == 0u256);
    assert(hi2 == 0u256);

    // Case 3
    let input3: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffu256;
    let (lo3, hi3) = split_challenge(input3);
    assert(lo3 == 0xffffffffffffffffffffffffffffffffu256);
    assert(hi3 == 0xffffffffffffffffffffffffffffffffu256);

    // Case 4
    let input4: u256 = 0xdeadbeefcafebabe1234567890abcdef00000000000000000000000000000000u256;
    let (lo4, hi4) = split_challenge(input4);
    assert(lo4 == 0u256);
    assert(hi4 == 0xdeadbeefcafebabe1234567890abcdefu256);
}

#[test]
fn test_eta_challenge() {
  let test_proof: Proof = get_test_proof();
  let public_inputs: [u256; 1] = [ 0x0000000000000000000000000000000000000000000000000000000000000002u256];
  let circuit_size: u256 = 0x1000u256;
  let pub_inputs_offset: u256 = 0x01; 
  let res: [u256; 4] = generate_eta_challenge(
      test_proof,
      public_inputs,
      circuit_size,
      pub_inputs_offset);

  /*
  Values from Remix:
      debug_eta = rp.eta;//177867169517319290814404739882896345685
      debug_etaTwo = rp.etaTwo;//15499021556754174612091921806072468430
      debug_etaThree = rp.etaThree;//16872579080600637296087620227697254429
      debug_previousChallenge = previousChallenge;//15370770787210484973313680373650403229959076469461600100864396152118878707741
  */
  assert(res[0] == 0x85cff885ac2961fd2caf69da4ab04a55u256);
  assert(res[1] == 0xba900c2ce087fada767d73013dfd3ceu256);
  assert(res[2] == 0xcb18a601c68a2bae386730f1ac8a01du256);
  assert(res[3] == 0x21fb8c477280b999953309afd419530d0cb18a601c68a2bae386730f1ac8a01du256);
}

#[test]
fn test_generate_beta_and_gamma_challenges() {
  let test_proof: Proof = get_test_proof();
  let previous_challenge = 0x21fb8c477280b999953309afd419530d0cb18a601c68a2bae386730f1ac8a01du256;
  let res = generate_beta_and_gamma_challenges(test_proof, previous_challenge);
  
  /*
  Values from Remix:
      debug_beta = rp.beta;//275384377054484130957265403122886851110
      debug_gamma = rp.gamma;//15424321275241768471824392717791660288
      debug_nextPreviousChallenge = nextPreviousChallenge;//5248624551688256932803201716183756399126196180589782341861028331705388710438
  */
  assert(res[0] == 0xcf2d1a0f78861f5dfc916c1550073a26u256);
  assert(res[1] == 0xb9a9dc0b29d2edaa5de654ffd600900u256);
  assert(res[2] == 0xb9a9dc0b29d2edaa5de654ffd600900cf2d1a0f78861f5dfc916c1550073a26u256);
}

#[test]
fn test_generate_alpha_challenges() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0xb9a9dc0b29d2edaa5de654ffd600900cf2d1a0f78861f5dfc916c1550073a26u256;
    let (alphas, next_previous_challenge) = generate_alpha_challenges(test_proof, previous_challenge);
    // Checking next_previous_challenge 13005457621940006761127482646048167441843516953077208194751712609578723040399
    assert(next_previous_challenge == 0x1cc0d40209bd4d716d361331241c1511046f57e033db8254d98224627eefdc8fu256);
}

#[test]
fn test_generate_gate_challenges() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0x1cc0d40209bd4d716d361331241c1511046f57e033db8254d98224627eefdc8fu256;
    let (gate_challenges, next_previous_challenge): ([u256; 28], u256) = generate_gate_challenges(previous_challenge);
    // Checking next_previous_challenge 4317761010121426231012984966520952426527325328231871435110638611957517199213
    assert(next_previous_challenge == 0x98bc420f59bb71d62ff761415930d401768c5da49ceb768761734d472f9276du256); 
}

#[test]
fn test_generate_sumcheck_challenges() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0x98bc420f59bb71d62ff761415930d401768c5da49ceb768761734d472f9276du256;
    let (sumcheck_challenges, next_previous_challenge): ([u256; 28], u256) = generate_sumcheck_challenges(test_proof, previous_challenge);
    // Checking next_previous_challenge 19616050979116386935205273601232869317989249797150412708821051478360919221126
    assert(next_previous_challenge == 0x2b5e4a99707a3c5940842a31aafe9bd8d7f39ece57c21ce2ec232b21ba69a386u256); 
}

#[test]
fn test_generate_rho_challenges() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0x2b5e4a99707a3c5940842a31aafe9bd8d7f39ece57c21ce2ec232b21ba69a386u256;
    let (rho_challenges, rho, next_previous_challenge): ([u256; 41], u256, u256) = generate_rho_challenge(test_proof, previous_challenge);
    // Checking rho 294785282843596535463692456146082517809
    // next_previous_challenge 4952713673987021976935340890088322591464923288178184511553792163194622759729
    assert(rho == 0xddc594911e07b3b91b1afc817c04d331u256);
    assert(next_previous_challenge == 0xaf322f838b1d65b67148cda28a6947addc594911e07b3b91b1afc817c04d331u256); 
}

#[test]
fn test_generate_gemini_R_challenge() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0xaf322f838b1d65b67148cda28a6947addc594911e07b3b91b1afc817c04d331u256;
    let (g_R, gemini_R, next_previous_challenge): ([u256; 109], u256, u256) = generate_gemini_R_challenge(test_proof, previous_challenge);
    // Checking gemini_R 26359775737884431470717459501741686932
    // next_previous_challenge 15748635582551239840220797616053854489678605924721899489793929438944840302740
    assert(gemini_R == 0x13d4b548ccd7ae5c493dd24a5302c094u256);
    assert(next_previous_challenge == 0x22d1696fad660cb58c619df7f8b6fa1413d4b548ccd7ae5c493dd24a5302c094u256); 
}

#[test]
fn test_generate_shplonk_nu_challenge() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0x22d1696fad660cb58c619df7f8b6fa1413d4b548ccd7ae5c493dd24a5302c094u256;
    let (shplonk_nu_challenge_elements, shplonk_nu, next_previous_challenge): ([u256; 29], u256, u256) = generate_shplonk_nu_challenge(test_proof, previous_challenge);
    // Checking shplonk_nu 251669737934598833684564868172863927504
    // next_previous_challenge 20935343517304992325213679253706309150493937786101295383338093080531471856848
    assert(shplonk_nu == 0xbd55d4148a8968c31c54c7f9b04a74d0u256);
    assert(next_previous_challenge == 0x2e48fc096952a1db3f13164812e32e24bd55d4148a8968c31c54c7f9b04a74d0u256); 
}

#[test]
fn test_generate_shplonk_z_challenge() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0x2e48fc096952a1db3f13164812e32e24bd55d4148a8968c31c54c7f9b04a74d0u256;
    let (shplonk_Z_challenge, shplonk_Z, next_previous_challenge): ([u256; 5], u256, u256) = generate_shplonk_z_challenge(test_proof, previous_challenge);
    // Checking shplonk_Z 38041957214091005110671540594301147646
    // next_previous_challenge 21174946723375305722978660230035882366753324797652366557166446506008147335678
    assert(shplonk_Z == 0x1c9e9d4cde5bde269eed51b980ab19feu256);
    assert(next_previous_challenge == 0x2ed0985a44aa290763fbbcf64d9f32051c9e9d4cde5bde269eed51b980ab19feu256); 
}

#[test]
fn test_accumulate_arithmetic_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let domain_sep =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_0, evals_1) = accumulate_arithmetic_relation(p, domain_sep);
    // Checking evals[0] = 14979598223891636997005538676532855254226452840487669176734478533383732914245
    // evals[1] = 17315460490620615005855042644472382143809713161674126066583899617562579419452
    assert(evals_0 == 0x211e26f2ab39e8056bc7255eae59eed7b9567bb427e47db6902984fbd248e845u256);
    assert(evals_1 == 0x2648340d89b71ac28bc16b8aa17013c3225419d1cd5a3fa451e7d51a0b3bc13cu256);
}

#[test]
fn test_compute_public_input_delta() {
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let test_proof: Proof = get_test_proof();
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let res = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
    // Checking publicInputsDelta 198985474193317811123202254104783999361890484863074032099922728691182624111
    assert(res == 0x709f2d729ff2116e36666d4ff2068eb3d436e0c30b6d9ac8c1a1c847ac5d6fu256);
}

#[test]
fn test_accumulate_permutation_relations() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let public_inputs_delta = 0x709f2d729ff2116e36666d4ff2068eb3d436e0c30b6d9ac8c1a1c847ac5d6fu256;
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_2, evals_3): (u256, u256) = accumulate_permutation_relation(p, transcript.relation_parameters, domain_sep, public_inputs_delta);
    // Checking evals[2] = 16324708436283044367841568103340616551664685927781696145977325160775585376154
    // evals[3] 6979824214732545265505548025511650629281689437159351060340733870718184689756
    assert(evals_2 == 0x2417752166808d594ede28101bc077687f5cb2df8959bc35a0284092d8ec279au256);
    assert(evals_3 == 0xf6e70c5147cd18a245fdea2e16b4cfb8d9e28001fb8361d6c83cbff41c5905cu256);
}

#[test]
fn test_accumulate_log_derivative_lookup_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_4, evals_5): (u256, u256) = accumulate_log_derivative_lookup_relation(p, transcript.relation_parameters, domain_sep);
    // Checking evals[4] = 1903615771862285322297304926322915628042382909636534946787820049666813203322
    // evals[5] 18178139318302515804664723096504632458153689944542614100938279423679637322041
    assert(evals_4 == 0x43568894b9d7b1fa6537c305be0620851944722889fb1de56c15d9f7a40137au256);
    assert(evals_5 == 0x28307655accd278c6bfdccd24c58d47c5556308d44afb52c43351012cf857939u256);
}

#[test]
fn test_accumulate_delta_range_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_6, evals_7, evals_8, evals_9): (u256, u256, u256, u256) = accumulate_delta_range_relation(p, domain_sep);
    // Checking evals[6] = 19698798931404244543557833082085342225327217591278026620730132847729478157672
    // evals[7] 4947639561987796324415692217837682365257580087979212066321493812243723675097
    // evals[8] 256282808279667546105413635429393530964650936525346474236019489198808638203
    // evals[9] 4499472263287742615102896649881176227257387525149051435823689078860105940624
    assert(evals_6 == 0x2b8d2005933fee9ea91ff5ba474d039712ea62273f41bbc3e78e394ae56b4568u256);
    assert(evals_7 == 0xaf043c6f274da611ac49f3db7bb9a3e6e31fa18a0b099c505180a6f228765d9u256);
    assert(evals_8 == 0x910d09b017d8e77fbcd6aeeb0ecaf20dad9e074a2186a446409a809a6222fbu256);
    assert(evals_9 == 0x9f29c6df037472d3a244aa2818d7875380f363d20184999a6587f384e347e90u256);
}

#[test]
fn test_accumulate_elliptic_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_10, evals_11): (u256, u256) = accumulate_elliptic_relation(p, domain_sep);
    // Checking evals[10] = 19647868464692598097004718933841352886604440934107898708318911517438277951611
    // evals[11] 3434974967945835896804449290853673872672295584058217391444702509957413441973
    assert(evals_10 == 0x2b704ca992442134aeb635c38eba9ebb64309dcf09bd7bf4f921a046b5d9a07bu256);
    assert(evals_11 == 0x798207ec91e683aeffaf4b7417c5a7396442d2db41e21a632063604ef9d91b5u256);
}

#[test]
fn test_accumulate_auxiliary_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_12, evals_13, evals_14, evals_15, evals_16, evals_17): (u256, u256, u256, u256, u256, u256) = accumulate_auxiliary_relation(p, transcript.relation_parameters, domain_sep);
    /*
    Check values
    936995614265411065839776816557343392430064966689065542959929822753570009379
    17761510163473853468540710431034323069065344467284449559664089587044873825936
    9955574710343601489387981690609409811442723544754483006784934782015859865368
    16091422934591472424619427748056157177237452789331642923036489276551065786007
    19872528008943687274507459597432359234158958293055730961947260828195696808136
    19291862890653629359326739619600180667702903595759938556188401706777059388578
    */
    assert(evals_12 == 0x212521af4bcadd1e01f3a6e7dc456fa5bbdcbe3c052fb097795a65b61f9b123u256);
    assert(evals_13 == 0x2744a893704465788917eb73e366fd159291346ab1e319db598543a81dee6e90u256);
    assert(evals_14 == 0x1602a7d57e0a68424969b57af661a9ef13b2b0cfcb60c76c78c62ffe5ac03718u256);
    assert(evals_15 == 0x23936c3139161601c19759f13d976120fb04b185d1e64ae50e6e1bb87e245697u256);
    assert(evals_16 == 0x2bef73c7346f121fa9e36c8ca611f3d396b6f0dbb59790b7ab75b453cf7610c8u256);
    assert(evals_17 == 0x2aa6ceb4ec1c6a60502b13fdb73ae218a471735ff537c99ffa77c43a696deca2u256);
}

#[test]
fn test_accumulate_poseidon_external_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_18, evals_19, evals_20, evals_21): (u256, u256, u256, u256) = accumulate_poseidon_external_relation(p, domain_sep);
    // Checking evals[18] = 9109203921032934693727094158554809536017130195015758329284596590123285213644
    // 6111346053738668940067201323854950530667557746661921783986809349286697664956
    // 18281447426842397003340399971183446576283748205726777608256206459456555174463
    // 6031792001353361769179456428486463842397126408647928385463378632931756055396
    assert(evals_18 == 0x1423a0701e1be8f6a495d760775439832eea8acda60ec86de24eb5e6437bf1ccu256);
    assert(evals_19 == 0xd82e637b70ead79af8b070247bac67eb11d4b55f7a93662d735b045c05c81bcu256);
    assert(evals_20 == 0x286aeebc6420cd53b1b253ba5b8e85654a133efb8c921320823b25d5217dca3fu256);
    assert(evals_21 == 0xd55df8fe92ed4433a600d999f2f85b77e5ed4882c5acafd9f2a2e8cba119b64u256);
}

#[test]
fn test_accumulate_poseidon_internal_relation() {
    let test_proof: Proof = get_test_proof();
    let p = test_proof.sumcheck_evaluations;
    let domain_sep = 0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_22, evals_23, evals_24, evals_25): (u256, u256, u256, u256) = accumulate_poseidon_internal_relation(p, domain_sep);

    /*
    11921018212328748633450283580342201217242695818272810654279932671154012181183
    20313336800531962073074227900686750393577066901355387366580843129973928697274
    1852027309498392217319388149119552662113350131034696149569279801886423890358
    12868281570375847534984943391932242763603893013989437819730217976558731070823
    */
    assert(evals_22 == 0x1a5b0ea4c19a9fd8be25d36c0cf6a965e2c1281d982bbc81cc720b9fafe252bfu256);
    assert(evals_23 == 0x2ce8f0f203e30852e2c61b853b0fbe68fc2a31c6bcf88c73e32e3d7165d11dbau256);
    assert(evals_24 == 0x41835d6e056d7fe5165db067cc06da6e5683485c9e5864cb068918e382bb9b6u256);
    assert(evals_25 == 0x1c7330737f04226151e40da2c3d72116f59d441db5babb7d2d03bac0628f0d67u256);
}

#[test]
fn test_scale_and_batch_subrelations() {
    let mut evaluations: [u256; 26] = [0u256; 26];
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0xb9a9dc0b29d2edaa5de654ffd600900cf2d1a0f78861f5dfc916c1550073a26u256;
    let (alphas, next_previous_challenge) = generate_alpha_challenges(test_proof, previous_challenge);
    let p = test_proof.sumcheck_evaluations;
    let domain_sep =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let (evals_0, evals_1) = accumulate_arithmetic_relation(p, domain_sep);
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let public_inputs_delta = 0x709f2d729ff2116e36666d4ff2068eb3d436e0c30b6d9ac8c1a1c847ac5d6fu256;
    let (evals_2, evals_3): (u256, u256) = accumulate_permutation_relation(p, transcript.relation_parameters, domain_sep, public_inputs_delta);
    let (evals_4, evals_5): (u256, u256) = accumulate_log_derivative_lookup_relation(p, transcript.relation_parameters, domain_sep);
    let (evals_6, evals_7, evals_8, evals_9): (u256, u256, u256, u256) = accumulate_delta_range_relation(p, domain_sep);
    let (evals_10, evals_11): (u256, u256) = accumulate_elliptic_relation(p, domain_sep);
    let (evals_12, evals_13, evals_14, evals_15, evals_16, evals_17): (u256, u256, u256, u256, u256, u256) = accumulate_auxiliary_relation(p, transcript.relation_parameters, domain_sep);
    let (evals_18, evals_19, evals_20, evals_21): (u256, u256, u256, u256) = accumulate_poseidon_external_relation(p, domain_sep);
    let (evals_22, evals_23, evals_24, evals_25): (u256, u256, u256, u256) = accumulate_poseidon_internal_relation(p, domain_sep);
    
    evaluations[0]  = evals_0;
    evaluations[1]  = evals_1;
    evaluations[2]  = evals_2;
    evaluations[3]  = evals_3;
    evaluations[4]  = evals_4;
    evaluations[5]  = evals_5;
    evaluations[6]  = evals_6;
    evaluations[7]  = evals_7;
    evaluations[8]  = evals_8;
    evaluations[9]  = evals_9;
    evaluations[10] = evals_10;
    evaluations[11] = evals_11;
    evaluations[12] = evals_12;
    evaluations[13] = evals_13;
    evaluations[14] = evals_14;
    evaluations[15] = evals_15;
    evaluations[16] = evals_16;
    evaluations[17] = evals_17;
    evaluations[18] = evals_18;
    evaluations[19] = evals_19;
    evaluations[20] = evals_20;
    evaluations[21] = evals_21;
    evaluations[22] = evals_22;
    evaluations[23] = evals_23;
    evaluations[24] = evals_24;
    evaluations[25] = evals_25;

    let accumulator: u256 = scale_and_batch_subrelations(evaluations, alphas);
    // Remix 297523481115958289824136345070231181576855192653361118600247121403995951114
    assert(accumulator == 0xa8646f42e40feeb5229b3425d2b91301015b5d795f6ce023b95eea4eb3100au256); 
}

#[test]
fn test_accumulate_relation_evaluations() {
    let test_proof: Proof = get_test_proof();
    let previous_challenge = 0xb9a9dc0b29d2edaa5de654ffd600900cf2d1a0f78861f5dfc916c1550073a26u256;
    let (alphas, next_previous_challenge) = generate_alpha_challenges(test_proof, previous_challenge);
    let pow_partial_evaluation =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let public_input_delta = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
    transcript.relation_parameters.public_inputs_delta = public_input_delta;
    let p = test_proof.sumcheck_evaluations;
    let res: u256 = accumulate_relation_evaluations(p, transcript.relation_parameters, alphas, pow_partial_evaluation);
    assert(transcript.relation_parameters.public_inputs_delta == 0x709f2d729ff2116e36666d4ff2068eb3d436e0c30b6d9ac8c1a1c847ac5d6fu256);
    assert(res == 0xa8646f42e40feeb5229b3425d2b91301015b5d795f6ce023b95eea4eb3100au256);
}

#[test]
fn test_compute_next_target_sum() {
    // Test values from round 0
    let round_univariates: [u256; 8] = [
        0x260bb8f4003f6f97f12667799af770d7f55ab6db291142b739644e2416a60ed5u256,
        0xa58957ee0f23091c729de3ce689e78532d9316d50a82dda0a7da76fd959f12cu256,
        0x16a94abfde149ae21d5ebac7e6cad578bb3567ed577ed1cbb7fb654ed235667cu256,
        0x20d500a2f84754b9297994aa5d4a2b6c051e26660e0edc33cd5f1dd8ea6c29e8u256,
        0x2624113eb35b76553dab8a3240b6781289fcd943fb047057814374e561f4dbb5u256,
        0x11985551a82dd45248488195db95161301d5f944e8b7c8d325da02128eeb5941u256,
        0x26537cbf7d46ab78ab355367943d5514fbb6fb217ef138a6a7c9f5fab44748fbu256,
        0x2a3062907a4d6c6a37fb25324f092a3f40aab01c27b925e8749be6ce8fe6da52u256
    ];
    let round_challenge = 0x1d69fa8c0e4151e133f99f0f70ecbd6cu256;
    let res = compute_next_target_sum(round_univariates, round_challenge);
    // Check 3766345310146111533400237577976957327108603990950938996119187058554433103096
    assert(res == 0x853ad07e66ac7386fdcc14673b521c99c3f624ad3973655ecfac182f12ae4f8u256);
}

#[test]
fn test_partially_evaluate_pow() {
  let gate_challenge = 0x36d1e4d36f73c48f01b5d501835d3af2u256;
  let current_evaluation = 0x1u256;
  let round_challenge = 0x1d69fa8c0e4151e133f99f0f70ecbd6cu256;
  let res = partially_evaluate_pow(gate_challenge, current_evaluation, round_challenge);
  // Check 2848990255030130992068201142230237485551746727533316106484885149130802121389
  assert(res == 0x64c78a9c5a5e98f1fe65ca0b7c2829e35a2fb85dfe97453ef51017a0604caadu256);
}

#[test]
fn test_verify_sumcheck() {
  let test_proof: Proof = get_test_proof();
  let pow_partial_evaluation =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
  let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
  let circuit_size: u256 = 0x1000u256;
  let pub_inputs_offset: u256 = 0x01; 
  let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
  let public_input_delta = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
  transcript.relation_parameters.public_inputs_delta = public_input_delta;
  let sumcheck_verified = verify_sumcheck(test_proof, transcript); 
  assert(sumcheck_verified);
}

#[test(should_revert)]
fn test_verify_sumcheck_error() {
  let mut test_proof: Proof = get_test_proof();
  let pow_partial_evaluation =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
  let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
  let circuit_size: u256 = 0x1000u256;
  let pub_inputs_offset: u256 = 0x01; 
  let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
  let public_input_delta = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
  transcript.relation_parameters.public_inputs_delta = public_input_delta;

  // Corrupt proof to trigger Error
  test_proof.sumcheck_univariates[0] = [0u256; 8];
  let sumcheck_verified = verify_sumcheck(test_proof, transcript); 
  assert(sumcheck_verified);
}

#[test]
fn test_compute_fold_pos_evaluations() {
    let mut test_proof: Proof = get_test_proof();
    let pow_partial_evaluation =  0x2f38f923e230b750eb82a57b80638515ff5428713e1ccd81014c1eefa0ab87fu256;
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let public_input_delta = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
    transcript.relation_parameters.public_inputs_delta = public_input_delta;

    let sumcheck_u_challenges = transcript.sumcheck_u_challenges;
    let batched_eval_accumulator = 0x2605fba05969f077ee909f396e0542f22fedabe09713233e9ab327393bd2158bu256;
    let gemini_evaluations = test_proof.gemini_a_evaluations;
    let gemini_eval_challenge_powers = compute_squares(transcript.gemini_r);

    let array = compute_fold_pos_evaluations(
      sumcheck_u_challenges,
      batched_eval_accumulator,
      gemini_evaluations,
      gemini_eval_challenge_powers,
      LOG_N
    );
    assert(array[0] == 0xf13e334663bfdab0226fcf1d47987fc05737fa12b4ffd4994d50647cd283a75u256);
    assert(array[1] == 0x21472e898f079efc2adc5d2c889ced0b12a6ff48b8ba95a77222764510cdd300u256);
    assert(array[2] == 0x165869673d8b8942514a160ceb47f95847e53a7b56c47b83f1c70c430d9ed90eu256);
    assert(array[3] == 0x17600d2a76b023382862cbcd740ca9767f4ea91c40687b80b4769006fdeac22bu256);
    assert(array[4] == 0x2ae00ff3cb038c10c08143e924e4ad39ba3eb997ead49c581f39b7e95d7111ceu256);
    assert(array[5] == 0x7219b1dad81d5d091a01324ec83136395e896476f69f296608692af6571fc39u256);
    assert(array[6] == 0x2ea6d672b332e8751da6f77f4b1ed106015a88faf62fd3cd386699d430c64d6u256);
    assert(array[7] == 0xc56624cd811ad2693b541dc0a5105701a8162596e164979ff07de08db1be433u256);
    assert(array[8] == 0xa99c91352d2538cb92da615fb4d0699713ae855d7e49ab94c14f16816e4e62au256);
    assert(array[9] == 0x18e1c604902ba212186dca22a929258ae9c6a2adc2afe38ba07408bba2ee4955u256);
    assert(array[10] == 0xe638a71c5b1fbfc7e228f3f05d9b0c908bfde62c68ba1d6c831e779ef4be23eu256);
    assert(array[11] == 0x943f8b918ffba01dbe5838522946d528c07e35ca50b46d1032765abb68f158au256);
    assert(array[12] == 0);
    assert(array[13] == 0);
    assert(array[14] == 0);
    assert(array[15] == 0);
    assert(array[16] == 0);
    assert(array[17] == 0);
    assert(array[18] == 0);
    assert(array[19] == 0);
    assert(array[20] == 0);
    assert(array[21] == 0);
    assert(array[22] == 0);
    assert(array[23] == 0);
    assert(array[24] == 0);
    assert(array[25] == 0);
    assert(array[26] == 0);
    assert(array[27] == 0);
}

#[test]
fn test_convert_proof_point() {
    let test_proof = get_test_proof();
    let shplonk_q = test_proof.shplonk_q;
    let res = convert_proof_point(shplonk_q);
    // x 9002479397207807811214641551368047797328551619840026156268921302902595774857
    // y 21368486379160417290463823718079819637627547960174834379137201268533907011793
    assert(res.x == 0x13e7390783fe5af683f3fd42e36992b6da75e4f8a81d317243720dad0ff1e989u256);
    assert(res.y == 0x2f3e227b15a9ca9b70b6a2c258fd6c958792b377742e6942a2ba2fc9a961b8d1u256);
}

#[test]
fn test_verify_shplemini() {
    let test_proof: Proof = get_test_proof();
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let circuit_size: u256 = 0x1000u256;
    let pub_inputs_offset: u256 = 0x01; 
    let mut transcript: Transcript = generate_transcript(test_proof, public_inputs, circuit_size, pub_inputs_offset);
    let public_input_delta = compute_public_input_delta(public_inputs, test_proof.pairing_point_object, transcript.relation_parameters.beta, transcript.relation_parameters.gamma, pub_inputs_offset);
    transcript.relation_parameters.public_inputs_delta = public_input_delta;

    let test_vk: VerificationKey = get_test_vk();
    let res = verify_shplemini(
        test_proof,
        test_vk,
        transcript);
    assert(res);
}

#[test]
fn test_verify() {
    let test_proof: Proof = get_test_proof();
    let public_inputs: [u256;1] = [0x0000000000000000000000000000000000000000000000000000000000000002u256];
    let test_vk: VerificationKey = get_test_vk();
    let res = verify(
        test_proof,
        test_vk,
        public_inputs
    );
    assert(res);
}