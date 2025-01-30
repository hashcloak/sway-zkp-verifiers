contract;

use sway_ecc::G1Point;
use sway_ecc::Scalar;
use std::hash::Hash;
use std::hash::keccak256;
use std::bytes::Bytes;
use std::bytes_conversions::u256::*;

// https://github.com/man2706kum/sway_ecc/blob/main/verifier_fflonk.sol
// the above contract is generated using snarkjs 
// the file is taken as a reference as of now

//TODO: needs to be generated dynamically
const nPublic = 1;


const ZERO: u256 = 0;
// TODO: These parameters needs to be generated per contract
const n: u32 = 2048; // Domain size
// Verification Key data
const k1: u256 = 2; // Plonk k1 multiplicative factor to force distinct cosets of H
const k2: u256 = 3; // Plonk k2 multiplicative factor to force distinct cosets of H
// OMEGAS
// Omega, Omega^{1/3}
const w1: u256 = 0x27A358499C5042BB4027FD7A5355D71B8C12C177494F0CAD00A58F9769A2EE2u256;
const wr: u256 = 0x53D15BDEB61ABF86A2102D3BC623DEEDDFA0637D0A6FB1422BB7F902DBCCB01u256;
// Omega_3, Omega_3^2
const w3: u256 = 0x30644E72E131A029048B6E193FD84104CC37A73FEC2BC5E9B8CA0B2D36636F23u256;
const w3_2: u256 = 0xB3C4D79D41A917585BFC41088D8DAAA78B17EA66B99C90DDu256;
// Omega_4, Omega_4^2, Omega_4^3
const w4: u256 = 0x30644E72E131A029048B6E193FD841045CEA24F6FD736BEC231204708F703636u256;
const w4_2: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000000u256;
const w4_3: u256 = 0xB3C4D79D41A91758CB49C3517C4604A520CFF123608FC9CBu256;
// Omega_8, Omega_8^2, Omega_8^3, Omega_8^4, Omega_8^5, Omega_8^6, Omega_8^7
const w8_1: u256 = 0x2B337DE1C8C14F22EC9B9E2F96AFEF3652627366F8170A0A948DAD4AC1BD5E80u256;
const w8_2: u256 = 0x30644E72E131A029048B6E193FD841045CEA24F6FD736BEC231204708F703636u256;
const w8_3: u256 = 0x1D59376149B959CCBD157AC850893A6F07C2D99B3852513AB8D01BE8E846A566u256;
const w8_4: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000000u256;
const w8_5: u256 = 0x530D09118705106CBB4A786EAD16926D5D174E181A26686AF5448492E42A181u256;
const w8_6: u256 = 0xB3C4D79D41A91758CB49C3517C4604A520CFF123608FC9CBu256;
const w8_7: u256 = 0x130B17119778465CFB3ACAEE30F81DEE20710EAD41671F568B11D9AB07B95A9Bu256;

// Verifier preprocessed input C_0(x)·[1]_1
const C0x: u256 = 0x2BD05595AC6F85F0547E51771E315C64E2619EFAF837A14EF204336B3EC91B71u256;
const C0y: u256 = 0x124D334C9193216424BC3FB146BF31B2CF4F5AB55A1754390D11F85CEAB6AE47u256;

// Verifier preprocessed input x·[1]_2
const X2x1: u256 = 0x29CFD542842EE76BD236E1D6B836066715306F64BEB777A636FDE8B0D854588Au256;
const X2x2: u256 = 0x9FB0B69FC88C9A3F0EA92686239AAD7467C5D99785B5565C438F9AD82C07A52u256;
const X2y1: u256 = 0x1209CDBF8BFC573C289A96A855D5A3706D990DCCDCC5705FA214CE41B6C3ACBDu256;
const X2y2: u256 = 0x1A1D887CEB374F8E8A94E702AB4B477D8E8FFD837A80A1C5164641256EF08E51u256;

// Scalar field size
pub const q: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000001u256;
// Base field size
pub const qf: u256 = 0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD47u256;
// [1]_1
const G1x: u256 = 1;
const G1y: u256 = 2;
// [1]_2
pub const G2x1: u256 = 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6EDu256;
pub const G2x2: u256 = 0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2u256;
pub const G2y1: u256 = 0x12C85EA5DB8C6DEB4AAB71808DCB408FE3D1E7690C43D37B4CE6CC0166FA7DAAu256;
pub const G2y2: u256 = 0x90689D0585FF075EC9E99AD690C3395BC4B313370B38EF355ACDADCD122975Bu256;

// // Proof calldata
// // Byte offset of every parameter of the calldata
// // Polynomial commitments
// const pC1: u16       = 4 + 0;     // [C1]_1
// const pC2: u16       = 4 + 32*2;  // [C2]_1
// const pW1: u16       = 4 + 32*4;  // [W]_1
// const pW2: u16       = 4 + 32*6;  // [W']_1
// // Opening evaluations
// const pEval_ql: u16  = 4 + 32*8;  // q_L(xi)
// const pEval_qr: u16  = 4 + 32*9;  // q_R(xi)
// const pEval_qm: u16  = 4 + 32*10; // q_M(xi)
// const pEval_qo: u16  = 4 + 32*11; // q_O(xi)
// const pEval_qc: u16  = 4 + 32*12; // q_C(xi)
// const pEval_s1: u16  = 4 + 32*13; // S_{sigma_1}(xi)
// const pEval_s2: u16  = 4 + 32*14; // S_{sigma_2}(xi)
// const pEval_s3: u16  = 4 + 32*15; // S_{sigma_3}(xi)
// const pEval_a: u16   = 4 + 32*16; // a(xi)
// const pEval_b: u16   = 4 + 32*17; // b(xi)
// const pEval_c: u16   = 4 + 32*18; // c(xi)
// const pEval_z: u16   = 4 + 32*19; // z(xi)
// const pEval_zw: u16  = 4 + 32*20; // z_omega(xi)
// const pEval_t1w: u16 = 4 + 32*21; // T_1(xi omega)
// const pEval_t2w: u16 = 4 + 32*22; // T_2(xi omega)
// const pEval_inv: u16 = 4 + 32*23; // inv(batch) sent by the prover to avoid any inverse calculation to save gas,
// // we check the correctness of the inv(batch) by computing batch
// // and checking inv(batch) * batch == 1

// Memory data
// Challenges
// const pAlpha: u16 = 0; // alpha challenge
// const pBeta: u16 = 32; // beta challenge
// const pGamma: u16 = 64; // gamma challenge
// const pY: u16 = 96; // y challenge
// const pXiSeed: u16 = 128; // xi seed, from this value we compute xi = xiSeed^24
// const pXiSeed2: u16 = 160; // (xi seed)^2
// const pXi: u16 = 192; // xi challenge
// // Roots
// // S_0 = roots_8(xi) = { h_0, h_0w_8, h_0w_8^2, h_0w_8^3, h_0w_8^4, h_0w_8^5, h_0w_8^6, h_0w_8^7 }
// const pH0w8_0: u16 = 224;
// const pH0w8_1: u16 = 256;
// const pH0w8_2: u16 = 288;
// const pH0w8_3: u16 = 320;
// const pH0w8_4: u16 = 352;
// const pH0w8_5: u16 = 384;
// const pH0w8_6: u16 = 416;
// const pH0w8_7: u16 = 448;

// // S_1 = roots_4(xi) = { h_1, h_1w_4, h_1w_4^2, h_1w_4^3 }
// const pH1w4_0: u16 = 480;
// const pH1w4_1: u16 = 512;
// const pH1w4_2: u16 = 544;
// const pH1w4_3: u16 = 576;

// // S_2 = roots_3(xi) U roots_3(xi omega)
// // roots_3(xi) = { h_2, h_2w_3, h_2w_3^2 }
// const pH2w3_0: u16 = 608;
// const pH2w3_1: u16 = 640;
// const pH2w3_2: u16 = 672;
// // roots_3(xi omega) = { h_3, h_3w_3, h_3w_3^2 }
// const pH3w3_0: u16 = 704;
// const pH3w3_1: u16 = 736;
// const pH3w3_2: u16 = 768;

// const pPi: u16 = 800; // PI(xi)
// const pR0: u16 = 832; // r0(y)
// const pR1: u16 = 864; // r1(y)
// const pR2: u16 = 896; // r2(y)
// const pF: u16 = 928; // [F]_1, 64 bytes
// const pE: u16 = 992; // [E]_1, 64 bytes
// const pJ: u16 = 1056; // [J]_1, 64 bytes
// const pZh: u16 = 1184; // Z_H(xi)
// // From this point we write all the variables that must be computed using the Montgomery batch inversion
// const pZhInv: u16 = 1216; // 1/Z_H(xi)
// const pDenH1: u16 = 1248; // 1/( (y-h_1w_4) (y-h_1w_4^2) (y-h_1w_4^3) (y-h_1w_4^4) )
// const pDenH2: u16 = 1280; // 1/( (y-h_2w_3) (y-h_2w_3^2) (y-h_2w_3^3) (y-h_3w_3) (y-h_3w_3^2) (y-h_3w_3^3) )
// const pLiS0Inv: u16 = 1312; // Reserve 8 * 32 bytes to compute r_0(X)
// const pLiS1Inv: u16 = 1568; // Reserve 4 * 32 bytes to compute r_1(X)
// const pLiS2Inv: u16 = 1696; // Reserve 6 * 32 bytes to compute r_2(X)
// // Lagrange evaluations

// const pEval_l1: u16 = 1888;

// const lastMem: u16 = 1920;

// abi MyContract {
//     fn test_function() -> bool;
// }

// impl MyContract for Contract {
//     fn test_function() -> bool {
//         true
//     }
// }

// fflonk Proof
pub struct Proof {
    C1: G1Point,
    C2: G1Point,
    W: G1Point,
    W_dash: G1Point,
    q_L: Scalar,
    q_R: Scalar,
    q_M: Scalar,
    q_O: Scalar,
    q_C: Scalar,
    S_sigma_1: Scalar,
    S_sigma_2: Scalar,
    S_sigma_3: Scalar,
    a: Scalar,
    b: Scalar,
    c: Scalar,
    z: Scalar,
    z_omega: Scalar,
    T_1_omega: Scalar,
    T_2_omega: Scalar,
    batch_inv: Scalar, // inv(batch) sent by the prover to avoid any inverse calculation to save gas,
    // we check the correctness of the inv(batch) by computing batch
    // and checking inv(batch) * batch == 1
    // Source: https://github.com/iden3/snarkjs/blob/master/templates/verifier_fflonk.sol.ejs#L96
}

pub struct Roots {
    pub s0_h0w8: [u256;8],
    pub s1_h1w4: [u256;4],
    pub s2_h2w3: [u256;3],
    pub s2_h3w3: [u256;3]
}

pub struct Challenges {
    pub alpha: u256,
    pub beta: u256,
    pub gamma: u256,
    pub y: u256,
    pub xi_seed: u256,
    pub xi_seed2: u256,
    pub xi: u256,
}

pub struct Inverse_vars {
    pub pZhInv: u256,
    pub pDenH1: u256,
    pub pDenH2: u256,
    pub pLiS0Inv: [u256; 8],
    pub pLiS1Inv: [u256;4],
    pub pLiS2Inv: [u256;6],
}

impl u256 {
    fn addmod(self, other: u256) -> u256 {
        let mut res: u256 = 0;
        asm (rA: res, rB: self, rC: other, rD: q) {
        wqam rA rB rC rD;
        };
        res
    }

    fn mulmod(self, other: u256) -> u256 {
        let mut res: u256 = 0;
        asm (rA: res, rB: self, rC: other, rD: q) {
        wqmm rA rB rC rD;
        }
        res
    }

    fn submod(self, other: u256) -> u256 {
        let mut res: u256 = q - other;
        asm (rA: res, rB: self, rD: q) {
        wqam rA rB rA rD;
        }
        res
    }
}

pub fn check_field(v: Scalar) -> bool {
    v.x < q
}

fn check_input(proof: Proof) -> bool {
    if !G1Point::check_point_belongs_to_bn128_curve(proof.C1) {
        log("C1 point does not belong to the curve.");
        return false;
    }
    if !G1Point::check_point_belongs_to_bn128_curve(proof.C2) {
        log("C2 point does not belong to the curve.");
        return false;
    }
    if !G1Point::check_point_belongs_to_bn128_curve(proof.W) {
        log("W point does not belong to the curve.");
        return false;
    }
    if !G1Point::check_point_belongs_to_bn128_curve(proof.W_dash)
    {
        log("W_dash point does not belong to the curve.");
        return false;
    }
    if !check_field(proof.q_L) {
        log("q_L does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.q_R) {
        log("q_R does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.q_M) {
        log("q_M does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.q_O) {
        log("q_O does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.q_C) {
        log("q_C does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.S_sigma_1) {
        log("S_sigma_1 does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.S_sigma_2) {
        log("S_sigma_2 does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.S_sigma_3) {
        log("S_sigma_3 does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.a) {
        log("a does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.b) {
        log("b does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.c) {
        log("c does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.z) {
        log("z does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.z_omega) {
        log("z_omega does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.T_1_omega) {
        log("T_1_omega does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.T_2_omega) {
        log("T_2_omega does not belong to the Scalar field.");
        return false;
    }
    if !check_field(proof.batch_inv) {
        log("batch_inv does not belong to the Scalar field.");
        return false;
    }

    true
}


// challenges = (alpha, beta, gamma, y, xi_seed, xi_seed^2, xi)
// roots is needed for later computations
// last u256 is Z_H(xi)
fn compute_challenges(proof: &Proof, pub_signals: u256) -> (Challenges, Roots, u256) {
    let mut transcript: Bytes = Bytes::new();

    transcript.append(C0x.to_be_bytes());
    transcript.append(C0y.to_be_bytes());
    transcript.append(pub_signals.to_be_bytes());
    transcript.append(proof.C1.x.to_be_bytes());
    transcript.append(proof.C1.y.to_be_bytes());

    let mut beta = u256::from(keccak256(transcript));
    // TODO the mod function result into failing of test. why?
    // workaround: using the 256bit addmod 
    asm (rA: beta, rC: ZERO, rD: q) {
        wqam rA rA rC rD;
    };

    let mut gamma = u256::from(keccak256(beta.to_be_bytes()));
    asm (rA: gamma, rB: gamma, rC: ZERO, rD: q) {
        wqam rA rB rC rD;
    };

    let mut transcript2 = Bytes::new();

    transcript2.append(gamma.to_be_bytes());
    transcript2.append(proof.C2.x.to_be_bytes());
    transcript2.append(proof.C2.y.to_be_bytes());

    // Get xiSeed & xiSeed2
    let mut xi_seed = u256::from(keccak256(transcript2));
    asm (rA: xi_seed, rC: ZERO, rD: q) {
        wqam rA rA rC rD;
    };

    let mut xi_seed2: u256 = 0;
    asm (rA: xi_seed2, rB: xi_seed, rC: xi_seed, rD: q) {
        wqmm rA rB rC rD;
    };

    // Compute roots.S0.h0w8
    let mut H0w8_0: u256 = 0;
    asm (rA: H0w8_0, rB: xi_seed2, rC: xi_seed, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_1: u256 = 0;
    asm (rA: H0w8_1, rB: H0w8_0, rC: w8_1, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_2: u256 = 0;
    asm (rA: H0w8_2, rB: H0w8_0, rC: w8_2, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_3: u256 = 0;
    asm (rA: H0w8_3, rB: H0w8_0, rC: w8_3, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_4: u256 = 0;
    asm (rA: H0w8_4, rB: H0w8_0, rC: w8_4, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_5: u256 = 0;
    asm (rA: H0w8_5, rB: H0w8_0, rC: w8_5, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_6: u256 = 0;
    asm (rA: H0w8_6, rB: H0w8_0, rC: w8_6, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H0w8_7: u256 = 0;
    asm (rA: H0w8_7, rB: H0w8_0, rC: w8_7, rD: q) {
        wqmm rA rB rC rD;
    };

    // Compute roots.S1.h1w4
    let mut H1w4_0: u256 = 0;
    asm (rA: H1w4_0, rB: H0w8_0, rC: H0w8_0, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H1w4_1: u256 = 0;
    asm (rA: H1w4_1, rB: H1w4_0, rC: w4, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H1w4_2: u256 = 0;
    asm (rA: H1w4_2, rB: H1w4_0, rC: w4_2, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H1w4_3: u256 = 0;
    asm (rA: H1w4_3, rB: H1w4_0, rC: w4_3, rD: q) {
        wqmm rA rB rC rD;
    };

    // Compute roots.S2.h2w3
    let mut H2w3_0: u256 = 0;
    asm (rA: H2w3_0, rB: H1w4_0, rC: xi_seed2, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H2w3_1: u256 = 0;
    asm (rA: H2w3_1, rB: H2w3_0, rC: w3, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H2w3_2: u256 = 0;
    asm (rA: H2w3_2, rB: H2w3_0, rC: w3_2, rD: q) {
        wqmm rA rB rC rD;
    };

    // Compute roots.S2.h2w3
    let mut H3w3_0: u256 = 0;
    asm (rA: H3w3_0, rB: H2w3_0, rC: wr, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H3w3_1: u256 = 0;
    asm (rA: H3w3_1, rB: H3w3_0, rC: w3, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut H3w3_2: u256 = 0;
    asm (rA: H3w3_2, rB: H3w3_0, rC: w3_2, rD: q) {
        wqmm rA rB rC rD;
    };

    let mut xin: u256 = 0;
    asm (rA: xin, rB: H2w3_0, rC: H2w3_0, rD: q) {
        wqmm rA rB rC rD;
        wqmm rA rA rC rD;
    };

    let xi_challenge = xin;

    // Compute xi^n
    //TODO: power must  be generated per contract
    let power = 11;
    let mut i = 0;
    while i < power {
        xin = asm (rA: xin, rB: xin, rC: xin, rD: q) {
            wqmm rA rB rC rD;
            rA: u256
        };
        i = i + 1;
    }

    let q_minus_one = q - 1;

    xin = asm (rA: xin, rB: xin, rC: q_minus_one, rD: q) {
        wqam rA rB rC rD;
        rA: u256
    };

    let Zh = xin;
    // let ZhInv = xin; // We will invert later together with lagrange pols


    let mut transcript3 = Bytes::new();
    transcript3.append(xi_seed.to_be_bytes());
    transcript3.append(proof.q_L.x.to_be_bytes());
    transcript3.append(proof.q_R.x.to_be_bytes());
    transcript3.append(proof.q_M.x.to_be_bytes());
    transcript3.append(proof.q_O.x.to_be_bytes());
    transcript3.append(proof.q_C.x.to_be_bytes());
    transcript3.append(proof.S_sigma_1.x.to_be_bytes());
    transcript3.append(proof.S_sigma_2.x.to_be_bytes());
    transcript3.append(proof.S_sigma_3.x.to_be_bytes());
    transcript3.append(proof.a.x.to_be_bytes());
    transcript3.append(proof.b.x.to_be_bytes());
    transcript3.append(proof.c.x.to_be_bytes());
    transcript3.append(proof.z.x.to_be_bytes());
    transcript3.append(proof.z_omega.x.to_be_bytes());
    transcript3.append(proof.T_1_omega.x.to_be_bytes());
    transcript3.append(proof.T_2_omega.x.to_be_bytes());
    
    // Compute challenge.alpha
    let alpha = u256::from(keccak256(transcript3));
    asm (rA: alpha, rB: alpha, rC: ZERO, rD: q) {
        wqam rA rB rC rD;
    };

    let mut transcript4 = Bytes::new();
    transcript4.append(alpha.to_be_bytes());
    transcript4.append(proof.W.x.to_be_bytes());
    transcript4.append(proof.W.y.to_be_bytes());

    // Compute challenge.y
    let Y = u256::from(keccak256(transcript4));
    asm (rA: Y, rB: Y, rC: ZERO, rD: q) {
        wqam rA rB rC rD;
    };

    ( Challenges{ 
        alpha: alpha, 
        beta: beta, 
        gamma: gamma, 
        y: Y,
        xi_seed: xi_seed,
        xi_seed2: xi_seed2,
        xi: xi_challenge
        }, 
    Roots {
        s0_h0w8:[H0w8_0, H0w8_1, H0w8_2, H0w8_3, H0w8_4, H0w8_5, H0w8_6, H0w8_7], 
        s1_h1w4: [H1w4_0, H1w4_1, H1w4_2, H1w4_3], 
        s2_h2w3: [H2w3_0, H2w3_1, H2w3_2], 
        s2_h3w3: [H3w3_0, H3w3_1, H3w3_2]
        },
        Zh,
        )
}

fn compute_li_s0(roots: Roots, challenges: Challenges) -> [u256; 8] {

    let mut li_s0_inv: [u256; 8] = [0; 8];
    let root0 = roots.s0_h0w8[0];
    let y = challenges.y;

    let mut den1: u256 = 1;
    let eight: u256 = 8;
    asm (rA: den1, rC: root0, rD: q, rE: eight) {
        wqmm rA rA rC rD;
        wqmm rA rA rC rD;
        wqmm rA rA rC rD;
        wqmm rA rA rC rD;
        wqmm rA rA rC rD;
        wqmm rA rA rC rD;
        wqmm rA rE rA rD;
    }
    
    // i = 0
    let mut den2: u256 = roots.s0_h0w8[0];
    let mut den3: u256 = q - roots.s0_h0w8[0];

    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s0_inv[0], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 1
    let mut den2: u256 = roots.s0_h0w8[7];
    let mut den3: u256 = q - roots.s0_h0w8[1]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[1], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 2
    let mut den2: u256 = roots.s0_h0w8[6];
    let mut den3: u256 = q - roots.s0_h0w8[2]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[2], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 3
    let mut den2: u256 = roots.s0_h0w8[5];
    let mut den3: u256 = q - roots.s0_h0w8[3]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[3], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 4
    let mut den2: u256 = roots.s0_h0w8[4];
    let mut den3: u256 = q - roots.s0_h0w8[4]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[4], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 5
    let mut den2: u256 = roots.s0_h0w8[3];
    let mut den3: u256 = q - roots.s0_h0w8[5]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[5], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 6
    let mut den2: u256 = roots.s0_h0w8[2];
    let mut den3: u256 = q - roots.s0_h0w8[6]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[6], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 7
    let mut den2: u256 = roots.s0_h0w8[1];
    let mut den3: u256 = q - roots.s0_h0w8[7]; 
    asm (rA: den3, rC: challenges.y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s0_inv[7], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    return li_s0_inv;
}

fn compute_li_s1(roots: Roots, challenges: Challenges) -> [u256; 4] {

    let mut li_s1_inv = [0; 4];
    let root0 = roots.s1_h1w4[0];
    let y = challenges.y;

    let mut den1: u256 = 1;
    let four: u256 = 4;
    asm (rA: den1, rB: root0, rC: four, rE: q) {
        wqmm rA rA rB rE;
        wqmm rA rA rB rE;
        wqmm rA rA rC rE;
    }

    // i = 0
    let mut den2 = roots.s1_h1w4[0];
    let mut den3 = q - roots.s1_h1w4[0]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s1_inv[0], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 1
    let mut den2 = roots.s1_h1w4[3];
    let mut den3 = q - roots.s1_h1w4[1]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s1_inv[1], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 2
    let mut den2 = roots.s1_h1w4[2];
    let mut den3 = q - roots.s1_h1w4[2]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s1_inv[2], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    // i = 3
    let mut den2 = roots.s1_h1w4[1];
    let mut den3 = q - roots.s1_h1w4[3]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }    

    asm (rA: li_s1_inv[3], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    }

    return li_s1_inv;
    
}

fn compute_li_s2(roots: Roots, challenges: Challenges) -> [u256; 6] {

    let mut li_s2_inv = [0; 6];
    let y = challenges.y;

    let mut t1: u256 = roots.s2_h2w3[0];
    let mut t2: u256 = 0;
    let three: u256 = 3;
    asm (rA: t1, rB: three, rC: q, rD: t2, dE: challenges.xi, dF: w1) {
        wqmm rA rA rB rC;
        wqmm rD dE dF rC;
    }

    let mut t3: u256 = q - t2;
    t3 = t3.addmod(challenges.xi);
    let mut den1: u256 = 0;

    asm (rA: den1, rB: t1, rC: t3, rD: q) {
        wqmm rA rB rC rD;
    }

    // i = 0
    let mut den2: u256 = roots.s2_h2w3[0];
    let mut den3: u256 = q - roots.s2_h2w3[0];

    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[0], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    // i = 1
    let mut den2: u256 = roots.s2_h2w3[2];
    let mut den3: u256 = q - roots.s2_h2w3[1]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[1], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    // i = 2
    let mut den2: u256 = roots.s2_h2w3[1];
    let mut den3: u256 = q - roots.s2_h2w3[2]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[2], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    let mut t1: u256 = roots.s2_h3w3[0];
    let mut t2: u256 = 0; // xi*w1
    let three: u256 = 3;
    asm (rA: t1, rB: three, rC: q, rD: t2, dE: challenges.xi, dF: w1) {
        wqmm rA rA rB rC;
        wqmm rD dE dF rC;
    }

    let mut t3: u256 = q - challenges.xi;
    let mut den1: u256 = 0;

    asm (rA: den1, rB: t1, rC: t3, rD: q, rE: t2) {
        wqam rA rE rC rD;
        wqmm rA rA rB rD;
    };

    // i = 0
    let mut den2: u256 = roots.s2_h3w3[0];
    let mut den3: u256 = q - roots.s2_h3w3[0]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[3], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    // i = 1
    let mut den2: u256 = roots.s2_h3w3[2];
    let mut den3: u256 = q - roots.s2_h3w3[1]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[4], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    // i = 2
    let mut den2: u256 = roots.s2_h3w3[1];
    let mut den3: u256 = q - roots.s2_h3w3[2]; 
    asm (rA: den3, rC: y, rD: q) {
        wqam rA rA rC rD;
    }

    asm (rA: li_s2_inv[5], rB: den1, rC: den2, rD: den3, rE: q) {
        wqmm rA rB rC rE;
        wqmm rA rA rD rE;
    };

    li_s2_inv
}




// pZhInv, pDenH1, pDenH2, pLiS0Inv, pLiS1Inv, pLiS2Inv in order
fn inverse_array(ref mut array: Inverse_vars, ref mut pEval_l1: u256, pEval_inv: u256) -> (Inverse_vars, u256){
    
    let mut res: [u256; 22] = [0; 22];
    let mut acc = array.pZhInv;

    // pZhInv
    res[0] = acc;

    // pDenH1
    acc = acc.mulmod(array.pDenH1);
    res[1] = acc;

    // pDenH2
    acc = acc.mulmod(array.pDenH2);
    res[2] = acc;



    // pLiS0Inv
    acc = acc.mulmod(array.pLiS0Inv[0]);
    res[3] = acc;



    acc = acc.mulmod(array.pLiS0Inv[1]);
    res[4] = acc;   
    
    acc = acc.mulmod(array.pLiS0Inv[2]);
    res[5] = acc;

    acc = acc.mulmod(array.pLiS0Inv[3]);
    res[6] = acc;

    acc = acc.mulmod(array.pLiS0Inv[4]);
    res[7] = acc;

    acc = acc.mulmod(array.pLiS0Inv[5]);
    res[8] = acc;

    acc = acc.mulmod(array.pLiS0Inv[6]);
    res[9] = acc;

    acc = acc.mulmod(array.pLiS0Inv[7]);
    res[10] = acc;

    // pLiS1Inv
    acc = acc.mulmod(array.pLiS1Inv[0]);
    res[11] = acc;


    acc = acc.mulmod(array.pLiS1Inv[1]);
    res[12] = acc;   
    
    acc = acc.mulmod(array.pLiS1Inv[2]);
    res[13] = acc;

    acc = acc.mulmod(array.pLiS1Inv[3]);
    res[14] = acc;

    // pLiS2Inv
    acc = acc.mulmod(array.pLiS2Inv[0]);
    res[15] = acc;

    acc = acc.mulmod(array.pLiS2Inv[1]);
    res[16] = acc;   
    
    acc = acc.mulmod(array.pLiS2Inv[2]);
    res[17] = acc;

    acc = acc.mulmod(array.pLiS2Inv[3]);
    res[18] = acc;

    acc = acc.mulmod(array.pLiS2Inv[4]);
    res[19] = acc;

    acc = acc.mulmod(array.pLiS2Inv[5]);
    res[20] = acc;


    acc = acc.mulmod(pEval_l1);
    res[21] = acc;

    
    let mut inv = pEval_inv;

    // Before using the inverse sent by the prover the verifier checks inv(batch) * batch === 1
    assert(acc.mulmod(inv) == 1);

    acc = inv;
    
    inv = acc.mulmod(res[20]);

    log(res[19]);
    assert(res[19] == 0x287b50a35c0a42df4a9c99e28779cd779d617300f74a45cb441f2d90a1e57ec5u256);


    acc = acc.mulmod(pEval_l1);
    pEval_l1 = inv;

    inv = acc.mulmod(res[19]);
    acc = acc.mulmod(array.pLiS2Inv[5]);
    array.pLiS2Inv[5] = inv;

    inv = acc.mulmod(res[18]);
    acc = acc.mulmod(array.pLiS2Inv[4]);
    array.pLiS2Inv[4] = inv;

    inv = acc.mulmod(res[17]);
    acc = acc.mulmod(array.pLiS2Inv[3]);
    array.pLiS2Inv[3] = inv;

    inv = acc.mulmod(res[16]);
    acc = acc.mulmod(array.pLiS2Inv[2]);
    array.pLiS2Inv[2] = inv;

    inv = acc.mulmod(res[15]);
    acc = acc.mulmod(array.pLiS2Inv[1]);
    array.pLiS2Inv[1] = inv;

    inv = acc.mulmod(res[14]);
    acc = acc.mulmod(array.pLiS2Inv[0]);
    array.pLiS2Inv[0] = inv;

    inv = acc.mulmod(res[13]);
    acc = acc.mulmod(array.pLiS1Inv[3]);
    array.pLiS1Inv[3] = inv;

    inv = acc.mulmod(res[12]);
    acc = acc.mulmod(array.pLiS1Inv[2]);
    array.pLiS1Inv[2] = inv;

    inv = acc.mulmod(res[11]);
    acc = acc.mulmod(array.pLiS1Inv[1]);
    array.pLiS1Inv[1] = inv;

    inv = acc.mulmod(res[10]);
    acc = acc.mulmod(array.pLiS1Inv[0]);
    array.pLiS1Inv[0] = inv;

    inv = acc.mulmod(res[9]);
    acc = acc.mulmod(array.pLiS0Inv[7]);
    array.pLiS0Inv[7] = inv;

    inv = acc.mulmod(res[8]);
    acc = acc.mulmod(array.pLiS0Inv[6]);
    array.pLiS0Inv[6] = inv;

    inv = acc.mulmod(res[7]);
    acc = acc.mulmod(array.pLiS0Inv[5]);
    array.pLiS0Inv[5] = inv;

    inv = acc.mulmod(res[6]);
    acc = acc.mulmod(array.pLiS0Inv[4]);
    array.pLiS0Inv[4] = inv;

    inv = acc.mulmod(res[5]);
    acc = acc.mulmod(array.pLiS0Inv[3]);
    array.pLiS0Inv[3] = inv;

    inv = acc.mulmod(res[4]);
    acc = acc.mulmod(array.pLiS0Inv[2]);
    array.pLiS0Inv[2] = inv;

    inv = acc.mulmod(res[3]);
    acc = acc.mulmod(array.pLiS0Inv[1]);
    array.pLiS0Inv[1] = inv;

    inv = acc.mulmod(res[2]);
    acc = acc.mulmod(array.pLiS0Inv[0]);
    array.pLiS0Inv[0] = inv;

    inv = acc.mulmod(res[1]);
    acc = acc.mulmod(array.pDenH2);
    array.pDenH2 = inv;

    inv = acc.mulmod(res[0]);
    acc = acc.mulmod(array.pDenH1);
    array.pDenH1 = inv;

    // inv = acc.mulmod(res[0]);
    array.pZhInv = acc;

    // array.pZhInv = inv;

    (array, pEval_l1)

}

fn compute_inversion(roots: Roots, challenges: Challenges, zh_inv: u256, eval_inv: u256)  -> (Inverse_vars, u256){

    // 1/((y - h1) (y - h1w4) (y - h1w4_2) (y - h1w4_3))
    let y = challenges.y;
    let mut w: u256 = q - roots.s1_h1w4[0];
    w = w.addmod(y);

    let mut t = q - roots.s1_h1w4[1];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s1_h1w4[2];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s1_h1w4[3];
    t = t.addmod(y);
    w = w.mulmod(t);

    let den_h1 = w;

    // 1/((y - h2) (y - h2w3) (y - h2w3_2) (y - h3) (y - h3w3) (y - h3w3_2))
    let mut w: u256 = q - roots.s2_h3w3[0];
    w = w.addmod(y);

    let mut t = q - roots.s2_h3w3[1];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s2_h3w3[2];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s2_h2w3[0];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s2_h2w3[1];
    t = t.addmod(y);
    w = w.mulmod(t);

    let mut t = q - roots.s2_h2w3[2];
    t = t.addmod(y);
    w = w.mulmod(t);

    let den_h2 = w;

    let li_s0_inv = compute_li_s0(roots, challenges);
    let li_s1_inv = compute_li_s1(roots, challenges);
    let li_s2_inv = compute_li_s2(roots, challenges);

    let w: u256 = 1;
    let xi = challenges.xi;

    let t = xi.submod(w);
    let mut eval_l1 = t.mulmod(u256::from(n));

    let mut input: Inverse_vars = Inverse_vars {
        pZhInv: zh_inv,
        pDenH1: den_h1,
        pDenH2: den_h2,
        pLiS0Inv: li_s0_inv,
        pLiS1Inv: li_s1_inv,
        pLiS2Inv: li_s2_inv
    };

    inverse_array(input, eval_l1, eval_inv)
}

//TODO
// instead of pEval: [u256; 1] it will be [u256;max(nPublic, 1)]
fn compute_lagrange(zh: u256, ref mut pEval: [u256; 1]) -> [u256;1]{
    let mut w: u256 = 1;

    let mut i: u64 = 1;
    while (i <= u64::max(nPublic, 1)) {
        if i == 1 {
            pEval[0] = pEval[0].mulmod(zh);
        }

        else {
            pEval[i - 1] = w.mulmod(pEval[i - 1].mulmod(zh))
        }

        if i < u64::max(nPublic, 1) {
            w = w.mulmod(w1);
        }

        i = i + 1;
    }

    pEval
}

//TODO
// instead of pEval: [u256; 1] it will be [u256;max(nPublic, 1)]
// same for pPub
fn compute_pi(pEval: [u256;1], p_pub: [u256;1]) -> u256{
    let mut pi: u256 = 0;
    pi = pi.submod(pEval[0].mulmod(p_pub[0]));

    let mut i = 1;
    while i < nPublic {
        pi = pi.submod(pEval[i].mulmod(p_pub[i]));

        i = i + 1;
    }

    pi
}


// ONLY FOR TESTING
// so that we dont have to copy everytime in testing
const proof1: Proof = Proof{
    C1: G1Point {
            x: 0x221ad660d2575bbc12cd0f0e749a9456ecdec9a3b6cc3bbc94c03eb9232e3effu256, 
            y: 0x126bee477fc98c7cefe0e54f2ef51d03fc2358e604c57cb37c2673b2dddd101eu256,
        },
        C2: G1Point {
            x: 0x2f9f3ec75b8f81f765c9fb6eeb31fa1ca1b3204df38a2ff2bb22c46fbd9ff915u256,
            y: 0x2c7490abf30fb34d888cf1097be1af1377ec60cca19e57b4da3aa47d2d75dcf5u256,
        },
        W: G1Point {
            x: 0x1a5e23a437fa68b2ad59e2b67b7f32a06a761459a437a3a54ef23a5f237d95c7u256,
            y: 0x1211244f2addbb44a84ce4c774838690eedf20685b1fbf6a7544edecf41e1bbdu256,
        },
        W_dash: G1Point {
            x: 0x2f03ca7d95fe7908a1eee49bfc707bdb5a9efe3e6b466c8c996c917fc30b3de5u256,
            y: 0x019cf3081794350aede6c4691f0a61501d94dc2adbc8949c74659d67cb841163u256,
        },
        q_L: Scalar{
            x: 0x067125bdbc6964248b3e1fd02bdb7670a4733b25987cbaeb8ab9199320bb3b6du256,
        },
        q_R: Scalar {
            x: 0x23b69ef5466622623aea51b17c324e55a8f1e20b1572c6ba1fc9956db2bb8689u256,
        },
        q_M: Scalar {
            x: 0x0c542266f24f61387b34d6de59685c1325be0a39a908a79c7e39bf0b3c0d14e2u256,
        },
        q_O: Scalar {
            x: 0x2a51432f583fa236dc9cd7c3cf6b9915d8912fe2cbf8155694f1ed756b26abf7u256,
        },
        q_C: Scalar {
            x: 0x0000000000000000000000000000000000000000000000000000000000000000u256,
        },
        S_sigma_1: Scalar {
            x: 0x1ba150613d8b5bbba067f34c174b5d678d8c4ecd9dc4a75692e29a29fafe8c61u256,
        },
        S_sigma_2: Scalar {
            x: 0x20643c6dc3eec0f68103d94efd913aa1d0558d49df70ef95b65d62ddf864615fu256,
        },
        S_sigma_3: Scalar {
            x: 0x199ddc60fd5b390ceba8d2bb54967a8b78e063ef42d14bbe18b39656a6c39139u256,
        },
        a: Scalar {
            x: 0x1aece3ec4efb852d417f02d6722912e0fa228b7815d570e859019fdd456d4794u256,
        },
        b: Scalar {
            x: 0x0015ec5fef99ea0e8e3641abc74892482e7fac7a916be4067d6e101165e891efu256,
        },
        c: Scalar {
            x: 0x0237611fbb1cdc29a4e565219cc727497c09b25a2e2076b03ef491d107324552u256,
        },
        z: Scalar {
            x: 0x034348c3e8d591329f37054ac4a8e3ec56d75d5a821ad95833e59363e3687a17u256,
        },
        z_omega: Scalar {
            x: 0x30085eec676c53ce01951a1f9b5c67662cbdccc13d2ab180c6170cee7249f2e6u256,
        },
        T_1_omega: Scalar {
            x: 0x03e64174dcca0d13a4c765a3ea9e8107109f98151e24eef9df8ddaeb849e125au256,
        },
        T_2_omega: Scalar {
            x: 0x0ef990764d5a526d52fb17836be9502b36c4d59e644829e20762829f12556be9u256,
        },
        batch_inv: Scalar {
            x: 0x2172803eac8862f41ccc20cc1854cb1e4ec4327c8f3e791863dcd4a7eef0fb69u256,
        },
};

#[test]
fn test_check_input() {
    let _public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    assert(check_input(proof1) == true);
}

#[test]
fn test_challenge() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;

    let (challenge, _, _) = compute_challenges(&proof1, public_signal);
    let expected_beta: u256 = 0x020021ade096c7681a001bf89e1b6b078614be20ed11df702729e254cc4276b7u256;

    let beta = challenge.beta;
    assert(beta == expected_beta);

    let expected_gamma: u256 = 0x0562eb8e4aa6364743a62f7bb24c853c6a54f48c20623f8d27d3b7ce1970744du256;

    let gamma = challenge.gamma;
    assert(gamma == expected_gamma);

    let expected_alpha: u256 = 0x2865d5dd871ee509c9b29f95b2051e92d866ea10b18e6ca3033fd340a67e94e9u256;

    let alpha = challenge.alpha;
    assert(alpha == expected_alpha);

    let expected_y: u256 = 0x20fa6e3c5a74f67d1fb68ff35619c07fb69a5899c7ca21097356953bab2baee3u256;

    let y = challenge.y;
    assert(y == expected_y);

    let expected_xi: u256 = 0x11fdb4ddc0b2765f1d8cbfc856e9bffdff2cf134d37901c09dad275aa56684f7u256;
    let xi = challenge.xi;
    assert(xi == expected_xi);
}

#[test]
fn test_compute_li_s0() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let (challenges, roots, _) = compute_challenges(&proof1, public_signal);

    let expected_h0_w8_0 = 0x187355a96fcb8745237e92eb0ef7baa42241dd1e30ef9f671e57fd9acde6969cu256;
    let expected_h0_w8_1 = 0x243eef9bc893a36be21202391a8a54bb9b3fdca5d3ad60c8c0e7021496d7f05au256;
    let expected_h0_w8_2 = 0x182bd2fe1e6d0eb0adc4dddd7a6d9cfe8d1180447ec5175cc66387a72baeb6a2u256;
    let expected_h0_w8_3 = 0x285ee8f54f601c394f5088df086e40c01f517b57bb8b476b4a291391131555ceu256;
    let expected_h0_w8_4 = 0x17f0f8c9716618e494d1b2cb72899db905f20b2a48c9d12a2589f7f922196965u256;
    let expected_h0_w8_5 = 0x0c255ed7189dfcbdd63e437d66f703a18cf40ba2a60c0fc882faf37f59280fa7u256;
    let expected_h0_w8_6 = 0x18387b74c2c491790a8b67d90713bb5e9b226803faf459347d7e6decc451495fu256;
    let expected_h0_w8_7 = 0x0805657d91d183f068ffbcd77913179d08e26cf0be2e2925f9b8e202dceaaa33u256;

    let expected_h1_w4_0 = 0x1a0a8f74abcb1e36f07b004ff1ea3eeb88d38b2582dd14d99d5f2bc93ae2e690u256;
    let expected_h1_w4_1 = 0x208b0e4e4e155248fd60f8fea9479862fb94ec1ab164adfc750abc987a9e134eu256;
    let expected_h1_w4_2 = 0x1659befe356681f2c7d545668f9719719f605d22f6dc5bb7a682c9cab51d1971u256;
    let expected_h1_w4_3 = 0x0fd94024931c4de0baef4cb7d839bffa2c9efc2dc854c294ced738fb7561ecb3u256;

    let expected_h2_w3_0 = 0x03e34fdfcc73dec03a4e013b26da81485181bc4224eb565645e5ba678384782bu256;
    let expected_h2_w3_1 = 0x082ee53f1b7990e85b2247dd25640b5eb2c769297bd7822c6dfb7dab28515087u256;
    let expected_h2_w3_2 = 0x24521953f944308122dffc9e3542cbb623eac2dcd8f6980e9000bd81442a374fu256;

    let expected_h3_w3_0 = 0x27fcf8700b88d29603e60d12b217678e676189c1904bab953eb8cbac195175b0u256;
    let expected_h3_w3_1 = 0x1cb22abc3928a326e4d7dea3693611e6b727fa1bb93ea76d3495069e8ab73dcdu256;
    let expected_h3_w3_2 = 0x1c1979b97db1ca9687e29fb6e7b5374531de4cb3a9e88e20147618dd3bf74c85u256;


    assert(expected_h0_w8_0 == roots.s0_h0w8[0]);
    assert(expected_h0_w8_1 == roots.s0_h0w8[1]);
    assert(expected_h0_w8_2 == roots.s0_h0w8[2]);
    assert(expected_h0_w8_3 == roots.s0_h0w8[3]);
    assert(expected_h0_w8_4 == roots.s0_h0w8[4]);
    assert(expected_h0_w8_5 == roots.s0_h0w8[5]);
    assert(expected_h0_w8_6 == roots.s0_h0w8[6]);
    assert(expected_h0_w8_7 == roots.s0_h0w8[7]);

    assert(expected_h1_w4_0 == roots.s1_h1w4[0]);
    assert(expected_h1_w4_1 == roots.s1_h1w4[1]);
    assert(expected_h1_w4_2 == roots.s1_h1w4[2]);
    assert(expected_h1_w4_3 == roots.s1_h1w4[3]);

    assert(expected_h2_w3_0 == roots.s2_h2w3[0]);
    assert(expected_h2_w3_1 == roots.s2_h2w3[1]);
    assert(expected_h2_w3_2 == roots.s2_h2w3[2]);

    assert(expected_h3_w3_0 == roots.s2_h3w3[0]);
    assert(expected_h3_w3_1 == roots.s2_h3w3[1]);
    assert(expected_h3_w3_2 == roots.s2_h3w3[2]);  

    let res = compute_li_s0(roots, challenges);

    let expected = [
        0x1c6d2ee71c71526fec4bcb8e819869854ece270679d14f1ab256d713f6ac1737u256,
        0x0f2a91afffc699ef46a96123d1b01ed6b0438a6a3f286c4be7ae2bdac85d7686u256,
        0x075d22d72ea2b07cc459fd0e5d402fbd77eda32f1ded39e28a6a22a2d874bf52u256,
        0x03ebb0ea80a098fe5c9e12715507930dd9395cb551da9e5d985174d3e45d48c5u256,
        0x1675a86100c2a8c2451a1fe99a550126d7ce1fa7a2b0a8d44e046a4d42eb9960u256,
        0x23b845981d6d6142eabc8a544a3d4bd57658bc43dd598ba318ad1586713a3a11u256,
        0x2b85b470ee914ab56d0bee69bead3aeeaeaea37efe94be0c75f11ebe6122f145u256,
        0x2ef7265d9c936233d4c7d906c6e5d79e4d62e9f8caa759916809cc8d553a67d2u256,

    ];

    let mut i = 0;
    while i < 8 {
        assert(res[i] == expected[i]);
        i = i + 1;
    }
}

#[test]
fn test_compute_li_s1() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let (challenges, roots, _) = compute_challenges(&proof1, public_signal);

    let res = compute_li_s1(roots, challenges);

    let expected = [
        0x1e7a2cd2140dab225ac332b7ccf03512dca1eae4ec61d051d0464cbc237154d6u256,
        0x0c085554438b47fde7fb779f5c4dae038992ab01ae707f31a065a3b4517f47bcu256,
        0x1329660b6b25228b9a17e5df81c72c71cac62c965ebbe3ee51d84ebe715a8376u256,
        0x259b3d893ba785b00cdfa0f7f269b3811dd56c799cad350e81b8f7c6434c9090u256,
    ];

    let mut i = 0;
    while i < 4 {
        assert(res[i] == expected[i]);
        i = i + 1;
    }
}


#[test]
fn test_compute_li_s2() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let (challenges, roots, _) = compute_challenges(&proof1, public_signal);

    let res = compute_li_s2(roots, challenges);

    let expected = [
        0x278a4da82ca85851c76e3508830f61fd9240169c218a1d76fe1e11ec6b5836b4u256,
        0x2f17a33bfdd0b0f38696b858099e86688711e33d63e3718f7f484410c230ad0du256,
        0x0b679d57213c94866c6005024d6d6b9ddea7772c2b07a3da67c2bdc6073acdf3u256,
        0x18a530b5dbc02a20326f57cd82da3049abd687a653e865fc1df5dab80971ed68u256,
        0x1e34f44d5bf6a1283d958b250a582536c56dbf50399b058ed5f75e748b2d712eu256,
        0x2446460dfaaa9855e8ba16dc60bb41020fb7db69597c0069713b02010d4fe251u256,
    ];

    let mut i = 0;
    while i < 6 {
        assert(res[i] == expected[i]);
        i = i + 1;
    }
}

#[test]
fn test_compute_inversion() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let (challenges, roots, zh) = compute_challenges(&proof1, public_signal);

    //zh is store in zhinv for inverse computation
    let (inverse_val, pEval_l1)= compute_inversion(roots, challenges, zh, proof1.batch_inv.x);

    let expected_pDenH1 = 0x15ab61875d3945bbc9392b0354a9abfb40452f34a7fca0d1ccd0a7a8ff901a7cu256;
    let expected_pDenH2 = 0x0a76ee4974ad4ef57e0da374ff210416832ba953383594252e6e5e06dc22e110u256;
    let expected_zh_inv = 0x05f6cddef83e0436c0f841b938d13576be0f744a7586ce09c975b8566cabd5dcu256;

    assert(inverse_val.pDenH1 == expected_pDenH1);
    assert(inverse_val.pDenH2 == expected_pDenH2);
    assert(inverse_val.pZhInv == expected_zh_inv);
    
}


#[test]
fn test_inverse_array() {

    let public_signal: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let (challenges, roots, zh) = compute_challenges(&proof1, public_signal);

    let li_s0_inv = compute_li_s0(roots, challenges);
    let li_s1_inv = compute_li_s1(roots, challenges);
    let li_s2_inv = compute_li_s2(roots, challenges);

    let zhinv = 0x01598f1579591cfff18429ff3414deaa93eea4ac3d2d35c5baa01dfcd641410bu256;

    assert(zhinv == zh);

    let mut input: Inverse_vars = Inverse_vars {
        pZhInv: zhinv,
        pDenH1: 0x0cb4b66615150cef834dd66e874a8edd9b6c191786051dba8bc2ae313cd46a94u256,
        pDenH2: 0x1814c352e70920cbfa500b8e258ee80b56baecd8e6253e6ab16242413222a906u256,
        pLiS0Inv: li_s0_inv,
        pLiS1Inv: li_s1_inv,
        pLiS2Inv: li_s2_inv
    };
    let mut pEval_l1 = 0x1379ba86272ddce77f5f07305480430ce53c2729efce651a9e87d066c427ad07u256;
    //zh is store in zhinv for inverse computation
    let (inverse_vars,  pEval_l1)= inverse_array(input, pEval_l1, proof1.batch_inv.x);

    let expected_pDenH1 = 0x15ab61875d3945bbc9392b0354a9abfb40452f34a7fca0d1ccd0a7a8ff901a7cu256;
    let expected_pDenH2 = 0x0a76ee4974ad4ef57e0da374ff210416832ba953383594252e6e5e06dc22e110u256;
    let expected_zhInv = 0x05f6cddef83e0436c0f841b938d13576be0f744a7586ce09c975b8566cabd5dcu256;
    let expected_pEval_l1 = 0x1b35d84010cc45c98684149a7b2f550e506c345cfe3cd45644e27f9ac592fc63u256;
    let expected_li_s2_inv5 = 0x21c42d1f2ff09bec348936690cf6262eb7a91d7fcbf668afdfe3627d1b510470u256;
    let expected_li_s2inv5_before = 0x2446460dfaaa9855e8ba16dc60bb41020fb7db69597c0069713b02010d4fe251u256;

    assert(li_s2_inv[5] == expected_li_s2inv5_before);
    assert(pEval_l1 == expected_pEval_l1);
    assert(inverse_vars.pLiS2Inv[5] == expected_li_s2_inv5);
    assert(inverse_vars.pZhInv == expected_zhInv);
    assert(inverse_vars.pDenH1 == expected_pDenH1);
    assert(inverse_vars.pDenH2 == expected_pDenH2);

}

#[test]
fn test_u256_mod() {
    let x = 0x0cb4b66615150cef834dd66e874a8edd9b6c191786051dba8bc2ae313cd46a94u256;
    let y = 0x1814c352e70920cbfa500b8e258ee80b56baecd8e6253e6ab16242413222a906u256;
    let sum = x.addmod(y);
    let mul = x.mulmod(y);
    let sub = x.submod(y);
    assert(sum == 0x24C979B8FC1E2DBB7D9DE1FCACD976E8F22705F06C2A5C253D24F0726EF7139Au256);
    assert(mul == 0x14DB664E0FF45A13EAB40C763AA64F8FADAA56B57A8BD1948EBC21150D96815Du256);
    assert(sub == 0x250441860F3D8C4D414E1096E33CFF2F6CE5148719994FE11E426183FAB1C18Fu256);
}

#[test]
fn test_lagrange() {
    let zh = 0x01598f1579591cfff18429ff3414deaa93eea4ac3d2d35c5baa01dfcd641410bu256;
    let mut pEval_l1: [u256;1] = [0x1b35d84010cc45c98684149a7b2f550e506c345cfe3cd45644e27f9ac592fc63u256];

    let expected_output_eval_l1 = 0x2a27c4b302cf8686c6287181a80dc4c64d651d30adef81a5aa82af00d376c1f6u256;

    let output_eval_l1 = compute_lagrange(zh, pEval_l1);

    assert(expected_output_eval_l1 == output_eval_l1[0]);
}

#[test]
fn test_compute_pi() {
    let pEval: [u256;1] = [0x2a27c4b302cf8686c6287181a80dc4c64d651d30adef81a5aa82af00d376c1f6u256];
    let pPub: [u256;1] = [0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256];

    let expected_pi = 0x080a0e10ddb090705b01961e4d7237f5db4357e256601f403dfd94bf06fe5b38u256;

    let pi = compute_pi(pEval, pPub);
    assert(pi == expected_pi);
}