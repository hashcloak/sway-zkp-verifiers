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
const C0x: u256 = 0x2F4C853E1651CDC5D4DE1B8542A968056CA2B5265771E7608FE73BA5C200211Bu256;
const C0y: u256 = 0x226C212B5B13358AFAAE03F8F1C8100407591CB4F27E38C29DFFFC54050409B1u256;

// Verifier preprocessed input x·[1]_2
const X2x1: u256 = 0x139517050A2954C1A2446ED2A7C94F1C0F00FA6B53B8D79EA013B1E531E957D7u256;
const X2x2: u256 = 0x15B599F0B3F23D5A9D61CB4FB199B2902113E7B50235BDD4F8A35B267E779831u256;
const X2y1: u256 = 0x1ED10C907A77F346DEF71B43559420C09611360BF7290ED7574C54D8C4F103B0u256;
const X2y2: u256 = 0x90382A692FC523B9D1DC488FCB620932ABA18576EA9D772B116D24FFBB7168Eu256;

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
const pAlpha: u16 = 0; // alpha challenge
const pBeta: u16 = 32; // beta challenge
const pGamma: u16 = 64; // gamma challenge
const pY: u16 = 96; // y challenge
const pXiSeed: u16 = 128; // xi seed, from this value we compute xi = xiSeed^24
const pXiSeed2: u16 = 160; // (xi seed)^2
const pXi: u16 = 192; // xi challenge
// Roots
// S_0 = roots_8(xi) = { h_0, h_0w_8, h_0w_8^2, h_0w_8^3, h_0w_8^4, h_0w_8^5, h_0w_8^6, h_0w_8^7 }
const pH0w8_0: u16 = 224;
const pH0w8_1: u16 = 256;
const pH0w8_2: u16 = 288;
const pH0w8_3: u16 = 320;
const pH0w8_4: u16 = 352;
const pH0w8_5: u16 = 384;
const pH0w8_6: u16 = 416;
const pH0w8_7: u16 = 448;

// S_1 = roots_4(xi) = { h_1, h_1w_4, h_1w_4^2, h_1w_4^3 }
const pH1w4_0: u16 = 480;
const pH1w4_1: u16 = 512;
const pH1w4_2: u16 = 544;
const pH1w4_3: u16 = 576;

// S_2 = roots_3(xi) U roots_3(xi omega)
// roots_3(xi) = { h_2, h_2w_3, h_2w_3^2 }
const pH2w3_0: u16 = 608;
const pH2w3_1: u16 = 640;
const pH2w3_2: u16 = 672;
// roots_3(xi omega) = { h_3, h_3w_3, h_3w_3^2 }
const pH3w3_0: u16 = 704;
const pH3w3_1: u16 = 736;
const pH3w3_2: u16 = 768;

const pPi: u16 = 800; // PI(xi)
const pR0: u16 = 832; // r0(y)
const pR1: u16 = 864; // r1(y)
const pR2: u16 = 896; // r2(y)
const pF: u16 = 928; // [F]_1, 64 bytes
const pE: u16 = 992; // [E]_1, 64 bytes
const pJ: u16 = 1056; // [J]_1, 64 bytes
const pZh: u16 = 1184; // Z_H(xi)
// From this point we write all the variables that must be computed using the Montgomery batch inversion
const pZhInv: u16 = 1216; // 1/Z_H(xi)
const pDenH1: u16 = 1248; // 1/( (y-h_1w_4) (y-h_1w_4^2) (y-h_1w_4^3) (y-h_1w_4^4) )
const pDenH2: u16 = 1280; // 1/( (y-h_2w_3) (y-h_2w_3^2) (y-h_2w_3^3) (y-h_3w_3) (y-h_3w_3^2) (y-h_3w_3^3) )
const pLiS0Inv: u16 = 1312; // Reserve 8 * 32 bytes to compute r_0(X)
const pLiS1Inv: u16 = 1568; // Reserve 4 * 32 bytes to compute r_1(X)
const pLiS2Inv: u16 = 1696; // Reserve 6 * 32 bytes to compute r_2(X)
// Lagrange evaluations

const pEval_l1: u16 = 1888;

const lastMem: u16 = 1920;

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


// challenges = (alpha, beta, gamma, y)
fn compute_challenges(proof: &Proof, pub_signals: u256) -> (Scalar, Scalar, Scalar, Scalar) {
    let mut transcript: Bytes = Bytes::new();

    transcript.append(C0x.to_be_bytes());
    transcript.append(C0y.to_be_bytes());
    transcript.append(pub_signals.to_be_bytes());
    transcript.append(proof.C1.x.to_be_bytes());
    transcript.append(proof.C1.y.to_be_bytes());

    let mut beta = u256::from(keccak256(transcript));
    beta = asm (rA, rB: beta, rC: q) {
        mod rA rB rC;
        rA: u256
    };

    let mut gamma = u256::from(keccak256(beta.to_be_bytes()));
    gamma = asm (rA, rB: gamma, rC: q) {
        mod rA rB rC;
        rA: u256
    };

    let mut transcript2 = Bytes::new();

    transcript2.append(gamma.to_be_bytes());
    transcript2.append(proof.C2.x.to_be_bytes());
    transcript2.append(proof.C2.y.to_be_bytes());

    // Get xiSeed & xiSeed2
    let mut xi_seed = u256::from(keccak256(transcript2));
    xi_seed = asm (rA, rB: xi_seed, rC: q) {
        mod rA rB rC;
        rA: u256
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
    };

    // Compute xi^n
    //TODO: power must  be generated per contract
    let power = 11;
    let mut i = 0;
    while i < power {
        let xin = asm (rA: xin, rB: xin, rC: xin, rD: q) {
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
    let ZhInv = xin; // We will invert later together with lagrange pols


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

    let mut transcript4 = Bytes::new();
    transcript4.append(alpha.to_be_bytes());
    transcript4.append(proof.W.x.to_be_bytes());
    transcript4.append(proof.W.y.to_be_bytes());

    // Compute challenge.y
    let Y = u256::from(keccak256(transcript4));


    (Scalar{
        x: alpha
    }, Scalar{
        x: beta
    }, Scalar{
        x: gamma
    }, Scalar{
        x: Y
    })
}