#!/usr/bin/env bash
# Relight a hex colour to a target HSL lightness. Shared by colorscheme-set.sh and the palette.json template so both writers of a generated config derive identical bytes; awk keeps the float math off python3 for the VPS.

gnohj_relight() {
  awk -v R="$((0x${1:1:2}))" -v G="$((0x${1:3:2}))" -v B="$((0x${1:5:2}))" -v L="$2" 'BEGIN{
    r=R/255; g=G/255; b=B/255
    mx=(r>g?(r>b?r:b):(g>b?g:b)); mn=(r<g?(r<b?r:b):(g<b?g:b)); l=(mx+mn)/2; d=mx-mn
    if(d==0){h=0;s=0} else {
      s=(l>0.5)?d/(2-mx-mn):d/(mx+mn)
      if(mx==r) h=((g-b)/d+((g<b)?6:0)); else if(mx==g) h=(b-r)/d+2; else h=(r-g)/d+4
      h/=6 }
    q=(L<0.5)?L*(1+s):L+s-L*s; p=2*L-q
    split("0 0 0",o)
    for(i=1;i<=3;i++){ t=h+(i==1?1/3:(i==2?0:-1/3)); if(t<0)t++; if(t>1)t--
      if(t<1/6) v=p+(q-p)*6*t; else if(t<1/2) v=q; else if(t<2/3) v=p+(q-p)*(2/3-t)*6; else v=p
      o[i]=int(v*255+0.5) }
    printf "#%02x%02x%02x", o[1], o[2], o[3] }'
}
