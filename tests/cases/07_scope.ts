console.log(add(1, 2));
function add(a: number, b: number): number { return a + b; }
function outer(): number {
  let x: number = 1;
  function inner(): number { return x; }
  return inner();
}
let x = 1;
{
  let x = "s";
  console.log(x);
}
x = 2;
if (true) { let y = 1; console.log(y); }
console.log(outer());
