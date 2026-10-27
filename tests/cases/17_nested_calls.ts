function add(a: number, b: number): number { return a + b; }
function mul(a: number, b: number): number { return a * b; }
let x: number = add(mul(2, 3), add(4, 5));
console.log(x);
console.log((1 + 2) * 3);
