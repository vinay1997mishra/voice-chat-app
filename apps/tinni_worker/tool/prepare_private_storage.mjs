// Run only with the existing CI Cloudflare credentials; do not log tokens or API bodies.
const account=process.env.CLOUDFLARE_ACCOUNT_ID;
const token=process.env.CLOUDFLARE_API_TOKEN;
if(!account||!token) throw new Error("Cloudflare deployment credentials are required");
const base="https://api.cloudflare.com/client/v4/accounts/"+encodeURIComponent(account)+"/r2/buckets";
const name="tinni-star-private-archives";
async function request(path,method="GET",body) {
  const response=await fetch(base+path,{method,headers:{Authorization:"Bearer "+token,"Content-Type":"application/json"},
    ...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(30000)});
  const data=await response.json();
  return {status:response.status,data};
}
let bucket=await request("/"+name);
if(bucket.status===404) {
  bucket=await request("","POST",{name});
  if(!bucket.data.success) throw new Error("Private R2 bucket creation failed (HTTP "+bucket.status+"). R2 Storage Write permission is required.");
} else if(!bucket.data.success) {
  throw new Error("Private R2 bucket check failed (HTTP "+bucket.status+"). R2 Storage Write permission is required.");
}
const managed=await request("/"+name+"/domains/managed");
if(!managed.data.success) throw new Error("Private bucket public-access verification failed (HTTP "+managed.status+")");
if(managed.data.result?.enabled) {
  const disabled=await request("/"+name+"/domains/managed","PUT",{enabled:false});
  if(!disabled.data.success) throw new Error("Private bucket public-access disable failed");
}
const custom=await request("/"+name+"/domains/custom");
if(!custom.data.success) throw new Error("Private bucket custom-domain verification failed (HTTP "+custom.status+")");
if((custom.data.result?.domains||[]).some(domain=>domain.enabled!==false)) {
  throw new Error("Private archive bucket has a public custom domain; deployment blocked");
}
console.log("Private archive bucket verified: managed public access disabled and no active custom domains.");
