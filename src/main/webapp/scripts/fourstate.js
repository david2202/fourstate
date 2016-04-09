function lookupAddress(dpid, success, error) {
    $.ajax({
        url: 'rest/deliveryPoint/' + dpid,
        type: 'GET',
        xhr: function() {
            var myXhr = $.ajaxSettings.xhr();
            if(myXhr.upload){ // Check if upload property exists
                //myXhr.upload.addEventListener('progress',progressHandlingFunction, false); // For handling the progress of the upload
            }
            return myXhr;
        },
        success:function (result) {success(result);},
        error: function (jqXHR, errorType, exception) {error(jqXHR, errorType, exception);},
        //Options to tell jQuery not to process data or worry about content-type.
        cache: false,
        contentType: false,
        processData: false
    });
}

// Sourced from

// The 4 bar types in numerical order
var bar_table = 'FADT';

// N Encoding Table (Numeric)
var n_decode = '012?345?678?9?? ';
var n_encode = make_encode_table(n_decode);

// C Encoding Table (Alphanumeric Characters)
var c_decode =
   'ABC DEF#GHIabcdeJKLfMNOgPQRhijklSTUmVWXnYZ0opqrs123t456u789vwxyz';
var c_encode = make_encode_table(c_decode);

function make_encode_table(decode) {
   var encode = new Object();
   for (var i = 0; i < decode.length; i++)
      encode[decode.charAt(i)] = i;
   return encode;
}

// Galois Field GF(64) operations.
// Primitive polynomial: 1 + x + x**6, generator element a == x
var gf_exp = new Array(128);  // table of a**i
var gf_log = new Array(64);   // gf_exp[gf_log[i]] == i if i != 0
var gf_root = new Array(32);  // solutions of x**2 + x + i == 0
var x = 1;
for (var i = 0; i < 63; i++) {
   gf_log[x] = i;
   gf_exp[i] = x;
   x <<= 1;
   if (x & 64) x ^= 67;
}
for (var i = 63; i < 128; i++) {
   // Note that a**(i+63) == a**i for all i.
   // Extend the table so we don't need to reduce exponents mod 63.
   gf_exp[i] = gf_exp[i-63];
}
for (var i = 0; i < 64; i += 2) {
   var x = gf_sq(i) ^ i;
   // By magic, x is always less than 32.
   gf_root[x] = i;
}

function gf_mul(x,y) {
   if (x == 0 || y == 0) return 0;
   return gf_exp[gf_log[x] + gf_log[y]];
}

function gf_div(x,y) {
   if (y == 0) return undefined;
   if (x == 0) return 0;
   return gf_exp[gf_log[x] + 63 - gf_log[y]];
}

function gf_sq(x) {
   if (x == 0) return 0;
   return gf_exp[gf_log[x] << 1];
}

function clean_str(str) {
   if (!str) str = '';
   return str.toUpperCase().replace(/\s/g, '');
}

function isdigits(str,n1) {
   // Is str composed of numeric digits and of length n1?
   if (/\D/.exec(str)) return false;
   return !n1 || str.length == n1;
}

function decode_bars(inf) {
   var len = inf.barcode.length;
   inf.bars = new Array(len);
   inf.bad_bar = new Array(len);
   for (var i = 0; i < len; i++) {
      switch (inf.barcode.charAt(i)) {
         case 'F':  case '0':  case 'H':
            inf.bars[i] = 0;
            break;
         case 'A':  case '1':
            inf.bars[i] = 1;
            break;
         case 'D':  case '2':
            inf.bars[i] = 2;
            break;
         case 'T':  case '3':  case 'S':
            inf.bars[i] = 3;
            break;
         default:
            inf.bars[i] = 3;
            inf.bad_bar[i] = true;
            inf.damaged = true;
            break;
      }
   }
}

function bars_to_symbols(inf) {
   // Convert bars to 6-bit GF(64) symbols
   var len = inf.full_length || inf.barcode.length;
   var nsymb = Math.ceil((len - 4) / 3);
   inf.symbols = new Array(nsymb);
   inf.erasures = [ ];
   for (var i = nsymb-1, pos = 2; i >= 0; i--, pos += 3) {
      inf.symbols[i] = ((inf.bars[pos]||0)<<4)
                     + ((inf.bars[pos+1]||0)<<2)
                     + (inf.bars[pos+2]||0);
      if (pos+2 >= inf.bars.length || inf.bad_bar[pos]
            || inf.bad_bar[pos+1] || inf.bad_bar[pos+2])
         inf.erasures.push(i);
   }
}

function symbols_to_bars(inf) {
   // Convert 6-bit GF(64) symbols to bars
   var len = 4 + inf.symbols.length*3;
   inf.bars2 = new Array(len);
   inf.bars2[0] = 1;
   inf.bars2[1] = 3;
   for (var i = inf.symbols.length-1, pos = 2; i >= 0; i--, pos += 3) {
      var n = inf.symbols[i];
      inf.bars2[pos] = n >> 4;
      inf.bars2[pos+1] = (n >> 2) & 3;
      inf.bars2[pos+2] = n & 3;
   }
   inf.bars2[len-2] = 1;
   inf.bars2[len-1] = 3;

   // Build corrected barcode
   inf.barcode2 = '';
   for (var i = 0; i < len; i++)
      inf.barcode2 += bar_table.charAt(inf.bars2[i]);
   if (inf.bars) {
      // Flag errors
      if (len > inf.bars.length) len = inf.bars.length;
      for (var i = 0; i < len; i++) {
         if (inf.bars[i] == inf.bars2[i]) {
            inf.bad_bar[i] = false;
         }
         else {
            inf.bad_bar[i] = true;
            inf.damaged = true;
         }
      }
   }
}

function syndromes(symbols) {
   // Evaluate the 4 Reed-Solomon syndromes by Horner's rule.
   // If there is no error, they should all be 0.
   var s1, s2, s3, s4;
   s1 = s2 = s3 = s4 = symbols[symbols.length-1];
   for (var i = symbols.length-2; i >= 0; i--) {
      if (s1 != 0) s1 = gf_exp[gf_log[s1] + 1];
      if (s2 != 0) s2 = gf_exp[gf_log[s2] + 2];
      if (s3 != 0) s3 = gf_exp[gf_log[s3] + 3];
      if (s4 != 0) s4 = gf_exp[gf_log[s4] + 4];
      var x = symbols[i];
      s1 ^= x;
      s2 ^= x;
      s3 ^= x;
      s4 ^= x;
   }
   return [s1, s2, s3, s4];
}

function iszero(s) {
   for (var i = 0; i < s.length; i++)
      if (s[i] != 0) return false;
   return true;
}

function find1err(s) {
   // Find the location of a single error in the Reed-Solomon codeword.
   if (s[0] == 0 || s[1] == 0) return null;
   return [ gf_log[gf_div(s[1], s[0])] ];
}

function find2errs(s) {
   // Use the Peterson-Gorenstein-Zierler procedure to find two errors.
   // First, calculate the error locator polynomial.
   // If this fails, there must not be two errors present.
   var d = gf_mul(s[0],s[2]) ^ gf_sq(s[1]);
   if (d == 0) return null;
   var a = gf_div(gf_sq(s[2]) ^ gf_mul(s[1],s[3]), d);
   if (a == 0) return null;
   var b = gf_div(gf_mul(s[1],s[2]) ^ gf_mul(s[0],s[3]), d);
   if (b == 0) return null;

   // Use the characteristic 2 version of the quadratic formula
   // to find the roots of a + b*x + x**2 == 0
   var c = gf_div(a, gf_sq(b));
   if (c & 32) return null;  // No solution
   var r = gf_mul(gf_root[c], b);
   // r != b since gf_root[c] is always even
   return [ gf_log[r], gf_log[r ^ b] ];
}

function find_errors(s, erasures) {
   if (erasures.length > 2) return null;  // No spare error-correcting capacity

   // Remove erasures from the syndromes
   var t = s.slice(0);
   for (var i = 0; i < erasures.length; i++) {
      var x = gf_exp[erasures[i]];
      for (var j = 0; j < t.length - 1; j++)
         t[j] = gf_mul(t[j],x) ^ t[j+1];
      t.pop();
   }
   if (iszero(t)) return null;

   if (t.length >= 4) {
      var e = find2errs(t);
      if (e) return e;
   }
   if (t.length >= 2) {
      var e = find1err(t);
      if (e) return e;
   }
   return null;
}

function correct_errors(s, symbols, erasures) {
   // Correct the errors using Forney's algorithm.
   // First, calculate the error evaluator polynomial.
   var w0 = s[0], w1 = s[1], w2 = s[2], w3 = s[3];
   for (var i = 0; i < erasures.length; i++) {
      if (erasures[i] >= symbols.length)
         return;  // Invalid error location
      var x = gf_exp[erasures[i]];
      w3 ^= gf_mul(x,w2);
      w2 ^= gf_mul(x,w1);
      w1 ^= gf_mul(x,w0);
   }

   // Evaluate it at the error locations to get the correction.
   for (var i = 0; i < erasures.length; i++) {
      var p = erasures[i];
      var x = gf_exp[63 - p];
      var n = gf_mul(gf_mul(gf_mul(w3,x) ^ w2, x) ^ w1, x) ^ w0;
      var d = gf_exp[erasures[i]];
      for (var j = 0; j < erasures.length; j++) {
         if (i != j)
            d = gf_mul(d, gf_exp[erasures[j] + 63 - p] ^ 1);
      }
      if (d == 0) return;  // Repeated error position?
      symbols[p] ^= gf_div(n, d);
   }
}

function check_errors(inf) {
   // Use Reed-Solomon error correcting code to fix errors and erasures.
   // An erasure is an error we know or suspect the location of.
   bars_to_symbols(inf);
   if (inf.erasures.length > 4) return;  // Too many to fix
   var s = syndromes(inf.symbols);
   if (inf.erasures.length == 0 && iszero(s)) return;  // No errors

   var e = find_errors(s, inf.erasures);
   if (e) inf.erasures = inf.erasures.concat(e);
   correct_errors(s, inf.symbols, inf.erasures);
   s = syndromes(inf.symbols);  // See if correction worked...
   if (iszero(s)) symbols_to_bars(inf);
}

function check_bar(pos, val, inf) {
   if (pos < inf.barcode.length && inf.bars[pos] != val) {
      inf.damaged = true;
      inf.bad_bar[pos] = true;
   }
}

function get_num(pos, len, strict, inf) {
   var num = '';
   var stop = Math.min(pos + len, inf.barcode.length) - 1;
   for (; pos < stop; pos += 2) {
      var n = (inf.bars[pos]<<2) + inf.bars[pos+1];
      var digit = n_decode.charAt(n);
      num += digit;
      if (digit == '?' || (strict && digit == ' ')) {
         inf.damaged = true;
         inf.bad_bar[pos] = true;
         inf.bad_bar[pos+1] = true;
      }
   }
   return num;
}

function get_alpha(pos, len, inf) {
   var alpha = '';
   var stop = Math.min(pos + len, inf.barcode.length) - 2;
   for (; pos < stop; pos += 3) {
      var n = (inf.bars[pos]<<4) + (inf.bars[pos+1]<<2) + inf.bars[pos+2];
      alpha += c_decode.charAt(n);
   }
   return alpha;
}

function decode_format(inf) {
   if (inf.format_code.length == 2) {
      switch (inf.format_code) {
         case '11':
            inf.format_type = 'Standard Customer Barcode';
            inf.full_length = 37;
            break;
         case '45':
            inf.format_type = 'Reply Paid Barcode';
            inf.full_length = 37;
            break;
         case '59':
            inf.format_type = 'Customer Barcode 2';
            inf.full_length = 52;
            break;
         case '62':
            inf.format_type = 'Customer Barcode 3';
            inf.full_length = 67;
            break;
         case '92':
            inf.format_type = 'Redirection Barcode';
            inf.full_length = 37;
            break;
         default:
            inf.format_type = 'Unknown Format Code';
            break;
      }
   }
}

function decode_barcode(inf) {
   if (inf.barcode.length == 0) return;
   decode_bars(inf);

   check_bar(0, 1, inf);
   check_bar(1, 3, inf);
   inf.format_code = get_num(2, 4, true, inf);
   decode_format(inf);
   inf.dpid = get_num(6, 16, true, inf);

   if (inf.full_length) {
      if (inf.full_length == 37)
         check_bar(22, 3, inf);
      else if (inf.customer_fmt == 'number')
         inf.customer_info = get_num(22, inf.full_length-36, false, inf);
      else if (inf.customer_fmt == 'alpha')
         inf.customer_info = get_alpha(22, inf.full_length-36, inf);
      else
         inf.customer_info = inf.barcode.substring(22, inf.full_length-14);

      check_bar(inf.full_length-2, 1, inf);
      check_bar(inf.full_length-1, 3, inf);

      if (inf.barcode.length > inf.full_length)
         inf.message = 'Barcode too long';
      else {
         check_errors(inf);
         if (inf.barcode.length < inf.full_length)
            inf.message = 'Incomplete barcode';
         else
            inf.message = 'Valid barcode';
      }
   } else {
      inf.message = 'Unknown format code ' + inf.format_code;
   }

   if (inf.damaged)
      inf.message = 'Damaged barcode';
}

function three_bars(symb) {
   return bar_table.charAt(symb >> 4)
      + bar_table.charAt((symb >> 2) & 3)
      + bar_table.charAt(symb & 3);
}

function add_check_digits(inf) {
   decode_bars(inf);
   bars_to_symbols(inf);
   var len = inf.symbols.length;
   // Divide by generator polynomial and keep remainder.
   // generator = (x - a)*(x - a**2)*(x - a**3)*(x - a**4)
   //           = 48 + 17*x + 29*x**2 + 30*x**3 + x**4
   var r1 = inf.symbols[len-1], r2 = inf.symbols[len-2];
   var r3 = inf.symbols[len-3], r4 = inf.symbols[len-4];
   for (var i = len - 5; i >= 0; i--) {
      var x = r1;
      r1 = gf_mul(x,30) ^ r2;
      r2 = gf_mul(x,29) ^ r3;
      r3 = gf_mul(x,17) ^ r4;
      r4 = gf_mul(x,48) ^ inf.symbols[i];
   }
   inf.barcode += three_bars(r1) + three_bars(r2)
      + three_bars(r3) + three_bars(r4);
}

function encode_num(num, len) {
   var code = '';
   var stop = Math.min(num.length, len>>1);
   for (var i = 0; i < stop; i++) {
      var n = n_encode[num.charAt(i)];
      if (n === undefined) {
         code += 'TT';
      }
      else {
         code += bar_table.charAt(n >> 2);
         code += bar_table.charAt(n & 3);
      }
   }
   for (var i = len - code.length; i > 0; i--)
      code += 'T';
   return code;
}

function encode_alpha(num, len) {
   var code = '';
   var stop = Math.min(num.length, Math.floor(len/3));
   for (var i = 0; i < stop; i++) {
      var n = c_encode[num.charAt(i)];
      if (n === undefined) {
         code += 'FFT';  // space
      }
      else {
         code += bar_table.charAt(n >> 4);
         code += bar_table.charAt((n >> 2) & 3);
         code += bar_table.charAt(n & 3);
      }
   }
   for (var i = len - code.length; i > 0; i--)
      code += 'T';
   return code;
}

function encode_barcode(inf) {
   inf.barcode = 'AT';

   if (inf.format_code)
      inf.barcode += encode_num(inf.format_code, 4);
   if (!isdigits(inf.format_code, 2))
      inf.message = 'Format code must be 2 digits';
   decode_format(inf);
   if (!inf.message && !inf.full_length)
      inf.message = 'Invalid format code';

   if (inf.dpid)
      inf.barcode += encode_num(inf.dpid, 16);
   if (!inf.message && !isdigits(inf.dpid, 8))
      inf.message = 'Sorting code must be 8 digits';

   if (inf.customer_info || (inf.format_code && inf.dpid)) {
      var cust_len = (inf.full_length || 37) - 36;
      if (cust_len == 1) {
         inf.barcode += 'T';
         if (!inf.message && inf.customer_info)
            inf.message = 'Customer information not allowed in this format';
      }
      else if (inf.customer_fmt == 'number') {
         var cust = clean_str(inf.customer_info);
         inf.barcode += encode_num(cust, cust_len);
         if (!inf.message) {
            if (!isdigits(cust))
               inf.message = 'Invalid customer information';
            else if (cust.length*2 > cust_len)
               inf.message = 'Customer information too long';
         }
      }
      else if (inf.customer_fmt == 'alpha') {
         inf.barcode += encode_alpha(inf.customer_info, cust_len);
         if (!inf.message) {
            if (/[^A-Za-z0-9 #]/.exec(inf.customer_info))
               inf.message = 'Invalid customer information';
            else if (inf.customer_info.length*3 > cust_len)
               inf.message = 'Customer information too long';
         }
      }
      else {
         var cust = new Object();
         cust.barcode = clean_str(inf.customer_info);
         decode_bars(cust);
         var stop = Math.min(cust.bars.length, cust_len);
         for (var i = 0; i < stop; i++)
            inf.barcode += bar_table.charAt(cust.bars[i]);
         for (; i < cust_len; i++)
            inf.barcode += 'T';
         if (!inf.message) {
            if (cust.damaged)
               inf.message = 'Invalid customer information';
            else if (cust.barcode.length > cust_len)
               inf.message = 'Customer information too long';
         }
      }
   }

   if (!inf.message) {
      add_check_digits(inf);
      inf.barcode += 'AT';
      inf.message = 'Valid barcode';
   }
}

function show_barcode(inf) {
   var top = document.getElementById('row0').cells;
   var mid = document.getElementById('row1').cells;
   var btm = document.getElementById('row2').cells;
   var barcode = inf.barcode;
   var len1 = barcode.length;
   if (inf.barcode2 && inf.barcode2.length > len1)
      barcode += inf.barcode2.substring(len1);
   var len = barcode.length;
   if (len > 67) len = 67;
   var i, c;
   for (i = 0; i < len; i++) {
      if (inf.bad_bar && inf.bad_bar[i])
         c = '#F00';
      else if (i < len1)
         c = '#000';
      else
         c = '#00F';
      switch (barcode.charAt(i)) {
         case 'F':  case '0':  case 'H':
            top[i].style.backgroundColor = c;
            mid[i].style.backgroundColor = c;
            btm[i].style.backgroundColor = c;
            break;
         case 'A':  case '1':
            top[i].style.backgroundColor = c;
            mid[i].style.backgroundColor = c;
            btm[i].style.backgroundColor = 'transparent';
            break;
         case 'D':  case '2':
            top[i].style.backgroundColor = 'transparent';
            mid[i].style.backgroundColor = c;
            btm[i].style.backgroundColor = c;
            break;
         case 'T':  case '3':  case 'S':
            top[i].style.backgroundColor = 'transparent';
            mid[i].style.backgroundColor = c;
            btm[i].style.backgroundColor = 'transparent';
            break;
         default:
            top[i].style.backgroundColor = '#f00';
            mid[i].style.backgroundColor = '#f00';
            btm[i].style.backgroundColor = '#f00';
            break;
      }
   }
   c = inf.full_length || 37;
   for (i = len; i < c; i++) {
      top[i].style.backgroundColor = 'transparent';
      mid[i].style.backgroundColor = '#ccc';
      btm[i].style.backgroundColor = 'transparent';
   }
   c = inf.full_length ? 'transparent' : '#eee';
   for (; i < 67; i++) {
      top[i].style.backgroundColor = 'transparent';
      mid[i].style.backgroundColor = c;
      btm[i].style.backgroundColor = 'transparent';
   }
}

function get_checked(btn) {
   for (var i = 0; i < btn.length; i++) {
      if (btn[i].checked)
         return btn[i].value;
   }
   return '';
}

var prev_action;

function do_decode(barcodeString) {
   var inf = new Object();
   inf.barcode = clean_str(barcodeString);
   inf.customer_fmt = "raw"; // Also can be alpha or number
   inf.message = '';
   inf.format_code = '';
   inf.format_type = '';
   inf.dpid = '';
   inf.customer_info = '';
   decode_barcode(inf);

   return inf;
}

function do_encode() {
   var decode_form = document.forms.decode_form;
   var encode_form = document.forms.encode_form;
   var inf = new Object();
   inf.message = '';
   inf.barcode = '';
   inf.format_code = clean_str(encode_form.format_code.value);
   inf.format_type = '';
   inf.dpid = clean_str(encode_form.dpid.value);
   inf.customer_info = encode_form.customer_info.value || '';
   inf.customer_fmt = get_checked(encode_form.customer_fmt);
   encode_barcode(inf);

   decode_form.barcode.value = inf.barcode;
   show_barcode(inf);
   document.getElementById('message_span').innerHTML = inf.message;
   document.getElementById('format_type').innerHTML = inf.format_type;
   prev_action = 'encode';
}

function do_again() {
   if (prev_action == 'decode')
      do_decode();
   else if (prev_action == 'encode')
      do_encode();
}

function generateBarcodeTable() {
    document.writeln('<table class="barcode">');
    for (var i = 0; i < 3; i++) {
        document.write('<tr id="row' + i + '">');
        for (var j = 0; j < 67; j++) {
            document.write('<td></td>');
        }
        document.writeln('</tr>');
    }
    document.writeln('</table>');
}