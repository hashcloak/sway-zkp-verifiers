# Generate Plonk verifier contract using snarkyjs

This works with [this branch](https://github.com/hashcloak/snarkjs/tree/sway-zkp-verifiers) of snarkjs. 
Follow the readme of https://github.com/hashcloak/snarkjs until step 25. 

## Generate Sway verifier contract

```=bash
zkey export swayverifier circuit0/circuit_final.zkey verifier0.sw
```

## Testing

This works with [this branch](https://github.com/hashcloak/snarkjs/tree/gen_testdata), which contains a script for testdata generation. 

Generate test data & function from proof and public data:
```=bash
zkey export swaycalldata circuit0/public.json circuit0/proof.json
```
