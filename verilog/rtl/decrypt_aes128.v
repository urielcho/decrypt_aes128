module decrypt_aes128 #(parameter Nk = 4)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input clk,
	 input decReset,
    input[127:0] in,
    input[Nk*32 - 1: 0] key,
    output reg [127:0]  out
);

localparam Nr = Nk+6;
localparam key_sch_len = (4*Nr+4) * 32 - 1;
reg [127:0] register;
wire [127:0] out_state;
wire [key_sch_len :0] k_sch;

Key_Expansion #(.Nk(Nk)) keys (key, k_sch); 



reg [3:0] round_counter = 0;
//reg [2:0] pulses_counter = 1;
    
//for(i = 1;i < Nr;i=i+1)  begin : generate_block 
Inv_round r (register,k_sch[key_sch_len - 128*(Nr - round_counter) -: 128], out_state); //4clk p
//end


//delay = Nr * 3

//last round
wire [127:0] sb,sr;
INV_Shift_Rows p2 (.in(register),.out(sb));
sub_bytes_inv p3 (.in(sb),.out(sr));


always @(posedge clk,posedge decReset) begin

    if(decReset) begin
	  round_counter=0;
	  out=0;
	  end
	  else
	  begin
    if(round_counter == 0) begin
        register <= in ^ k_sch[127 -: 128];
        round_counter <= 1;
    end
    else if(round_counter < Nr) begin
        register <= out_state;
        round_counter <= round_counter + 1;
    end 
    else begin
        out <= sr ^ k_sch[key_sch_len-:128];
    end
	 end
 end
    //$display("state[0]=%h in=%h k_sch=%h", state[0], in, k_sch[key_sch_len -: 128]);




endmodule

module Key_Expansion #(parameter Nk = 4) (
    key,out
);
localparam Nr = Nk+6;
localparam keylen = Nk*32;
//total number of out words Nr*4
input [keylen-1:0] key;
reg [14:0] temp;
wire [31:0] subword [0:4*Nr+3];
/* output reg [31:0] out[0:4*Nr+3]; */
output wire [(4*Nr+4) * 32 - 1:0] out;//

wire [31:0] out_words[0:4*Nr+3];

integer j;
genvar i;
generate 
    
    for(i = 0;i <=4*Nr+3;i=i+1)begin : generate_block
        if(i < Nk) begin
            assign out_words[i] = key[(keylen-1)-32*i -:32];
        end

        else begin
            if(i % Nk == 0) begin
                aes_sbox s0(RotWord(out_words[i-1]), subword[i]);
                assign out_words[i] = out_words[i-Nk] ^ subword[i] ^ rcon(i/Nk);
            end
            else if(Nk > 6 && i % Nk == 4) begin
                aes_sbox s1(out_words[i-1], subword[i]);
                assign out_words[i] = out_words[i-Nk] ^ subword[i];
            end
            else begin
                assign out_words[i] = out_words[i-Nk] ^ out_words[i-1];
            end
        end
        assign out[(4*Nr+4) * 32 - 1 - 32*i  -:32] = out_words[i];
    end
endgenerate 

function [31:0] RotWord;
    input [31:0] word;
    begin
        RotWord = {word[23-:8*3], word[31-:8]};
    end
    
endfunction

function [31:0] rcon;
    input [3:0] k;/* 256 => 14 round => 4 bit */
//integer j;
    begin
        case(k)
            4'h1: rcon=32'h01000000;
            4'h2: rcon=32'h02000000;
            4'h3: rcon=32'h04000000;
            4'h4: rcon=32'h08000000;
            4'h5: rcon=32'h10000000;
            4'h6: rcon=32'h20000000;
            4'h7: rcon=32'h40000000;
            4'h8: rcon=32'h80000000;
            4'h9: rcon=32'h1b000000;
            4'ha: rcon=32'h36000000;
            default: rcon=32'h00000000;
        endcase
    end
    
endfunction
endmodule

module aes_sbox(
                input wire [31 : 0]  sboxw,
                output wire [31 : 0] new_sboxw
               );


  //----------------------------------------------------------------
  // The sbox array.
  //----------------------------------------------------------------
  wire [7 : 0] sbox [0 : 255];


  //----------------------------------------------------------------
  // Four parallel muxes.
  //----------------------------------------------------------------
  assign new_sboxw[31 : 24] = sbox[sboxw[31 : 24]];
  assign new_sboxw[23 : 16] = sbox[sboxw[23 : 16]];
  assign new_sboxw[15 : 08] = sbox[sboxw[15 : 08]];
  assign new_sboxw[07 : 00] = sbox[sboxw[07 : 00]];


  //----------------------------------------------------------------
  // Creating the sbox array contents.
  //----------------------------------------------------------------
  assign sbox[8'h00] = 8'h63;
  assign sbox[8'h01] = 8'h7c;
  assign sbox[8'h02] = 8'h77;
  assign sbox[8'h03] = 8'h7b;
  assign sbox[8'h04] = 8'hf2;
  assign sbox[8'h05] = 8'h6b;
  assign sbox[8'h06] = 8'h6f;
  assign sbox[8'h07] = 8'hc5;
  assign sbox[8'h08] = 8'h30;
  assign sbox[8'h09] = 8'h01;
  assign sbox[8'h0a] = 8'h67;
  assign sbox[8'h0b] = 8'h2b;
  assign sbox[8'h0c] = 8'hfe;
  assign sbox[8'h0d] = 8'hd7;
  assign sbox[8'h0e] = 8'hab;
  assign sbox[8'h0f] = 8'h76;
  assign sbox[8'h10] = 8'hca;
  assign sbox[8'h11] = 8'h82;
  assign sbox[8'h12] = 8'hc9;
  assign sbox[8'h13] = 8'h7d;
  assign sbox[8'h14] = 8'hfa;
  assign sbox[8'h15] = 8'h59;
  assign sbox[8'h16] = 8'h47;
  assign sbox[8'h17] = 8'hf0;
  assign sbox[8'h18] = 8'had;
  assign sbox[8'h19] = 8'hd4;
  assign sbox[8'h1a] = 8'ha2;
  assign sbox[8'h1b] = 8'haf;
  assign sbox[8'h1c] = 8'h9c;
  assign sbox[8'h1d] = 8'ha4;
  assign sbox[8'h1e] = 8'h72;
  assign sbox[8'h1f] = 8'hc0;
  assign sbox[8'h20] = 8'hb7;
  assign sbox[8'h21] = 8'hfd;
  assign sbox[8'h22] = 8'h93;
  assign sbox[8'h23] = 8'h26;
  assign sbox[8'h24] = 8'h36;
  assign sbox[8'h25] = 8'h3f;
  assign sbox[8'h26] = 8'hf7;
  assign sbox[8'h27] = 8'hcc;
  assign sbox[8'h28] = 8'h34;
  assign sbox[8'h29] = 8'ha5;
  assign sbox[8'h2a] = 8'he5;
  assign sbox[8'h2b] = 8'hf1;
  assign sbox[8'h2c] = 8'h71;
  assign sbox[8'h2d] = 8'hd8;
  assign sbox[8'h2e] = 8'h31;
  assign sbox[8'h2f] = 8'h15;
  assign sbox[8'h30] = 8'h04;
  assign sbox[8'h31] = 8'hc7;
  assign sbox[8'h32] = 8'h23;
  assign sbox[8'h33] = 8'hc3;
  assign sbox[8'h34] = 8'h18;
  assign sbox[8'h35] = 8'h96;
  assign sbox[8'h36] = 8'h05;
  assign sbox[8'h37] = 8'h9a;
  assign sbox[8'h38] = 8'h07;
  assign sbox[8'h39] = 8'h12;
  assign sbox[8'h3a] = 8'h80;
  assign sbox[8'h3b] = 8'he2;
  assign sbox[8'h3c] = 8'heb;
  assign sbox[8'h3d] = 8'h27;
  assign sbox[8'h3e] = 8'hb2;
  assign sbox[8'h3f] = 8'h75;
  assign sbox[8'h40] = 8'h09;
  assign sbox[8'h41] = 8'h83;
  assign sbox[8'h42] = 8'h2c;
  assign sbox[8'h43] = 8'h1a;
  assign sbox[8'h44] = 8'h1b;
  assign sbox[8'h45] = 8'h6e;
  assign sbox[8'h46] = 8'h5a;
  assign sbox[8'h47] = 8'ha0;
  assign sbox[8'h48] = 8'h52;
  assign sbox[8'h49] = 8'h3b;
  assign sbox[8'h4a] = 8'hd6;
  assign sbox[8'h4b] = 8'hb3;
  assign sbox[8'h4c] = 8'h29;
  assign sbox[8'h4d] = 8'he3;
  assign sbox[8'h4e] = 8'h2f;
  assign sbox[8'h4f] = 8'h84;
  assign sbox[8'h50] = 8'h53;
  assign sbox[8'h51] = 8'hd1;
  assign sbox[8'h52] = 8'h00;
  assign sbox[8'h53] = 8'hed;
  assign sbox[8'h54] = 8'h20;
  assign sbox[8'h55] = 8'hfc;
  assign sbox[8'h56] = 8'hb1;
  assign sbox[8'h57] = 8'h5b;
  assign sbox[8'h58] = 8'h6a;
  assign sbox[8'h59] = 8'hcb;
  assign sbox[8'h5a] = 8'hbe;
  assign sbox[8'h5b] = 8'h39;
  assign sbox[8'h5c] = 8'h4a;
  assign sbox[8'h5d] = 8'h4c;
  assign sbox[8'h5e] = 8'h58;
  assign sbox[8'h5f] = 8'hcf;
  assign sbox[8'h60] = 8'hd0;
  assign sbox[8'h61] = 8'hef;
  assign sbox[8'h62] = 8'haa;
  assign sbox[8'h63] = 8'hfb;
  assign sbox[8'h64] = 8'h43;
  assign sbox[8'h65] = 8'h4d;
  assign sbox[8'h66] = 8'h33;
  assign sbox[8'h67] = 8'h85;
  assign sbox[8'h68] = 8'h45;
  assign sbox[8'h69] = 8'hf9;
  assign sbox[8'h6a] = 8'h02;
  assign sbox[8'h6b] = 8'h7f;
  assign sbox[8'h6c] = 8'h50;
  assign sbox[8'h6d] = 8'h3c;
  assign sbox[8'h6e] = 8'h9f;
  assign sbox[8'h6f] = 8'ha8;
  assign sbox[8'h70] = 8'h51;
  assign sbox[8'h71] = 8'ha3;
  assign sbox[8'h72] = 8'h40;
  assign sbox[8'h73] = 8'h8f;
  assign sbox[8'h74] = 8'h92;
  assign sbox[8'h75] = 8'h9d;
  assign sbox[8'h76] = 8'h38;
  assign sbox[8'h77] = 8'hf5;
  assign sbox[8'h78] = 8'hbc;
  assign sbox[8'h79] = 8'hb6;
  assign sbox[8'h7a] = 8'hda;
  assign sbox[8'h7b] = 8'h21;
  assign sbox[8'h7c] = 8'h10;
  assign sbox[8'h7d] = 8'hff;
  assign sbox[8'h7e] = 8'hf3;
  assign sbox[8'h7f] = 8'hd2;
  assign sbox[8'h80] = 8'hcd;
  assign sbox[8'h81] = 8'h0c;
  assign sbox[8'h82] = 8'h13;
  assign sbox[8'h83] = 8'hec;
  assign sbox[8'h84] = 8'h5f;
  assign sbox[8'h85] = 8'h97;
  assign sbox[8'h86] = 8'h44;
  assign sbox[8'h87] = 8'h17;
  assign sbox[8'h88] = 8'hc4;
  assign sbox[8'h89] = 8'ha7;
  assign sbox[8'h8a] = 8'h7e;
  assign sbox[8'h8b] = 8'h3d;
  assign sbox[8'h8c] = 8'h64;
  assign sbox[8'h8d] = 8'h5d;
  assign sbox[8'h8e] = 8'h19;
  assign sbox[8'h8f] = 8'h73;
  assign sbox[8'h90] = 8'h60;
  assign sbox[8'h91] = 8'h81;
  assign sbox[8'h92] = 8'h4f;
  assign sbox[8'h93] = 8'hdc;
  assign sbox[8'h94] = 8'h22;
  assign sbox[8'h95] = 8'h2a;
  assign sbox[8'h96] = 8'h90;
  assign sbox[8'h97] = 8'h88;
  assign sbox[8'h98] = 8'h46;
  assign sbox[8'h99] = 8'hee;
  assign sbox[8'h9a] = 8'hb8;
  assign sbox[8'h9b] = 8'h14;
  assign sbox[8'h9c] = 8'hde;
  assign sbox[8'h9d] = 8'h5e;
  assign sbox[8'h9e] = 8'h0b;
  assign sbox[8'h9f] = 8'hdb;
  assign sbox[8'ha0] = 8'he0;
  assign sbox[8'ha1] = 8'h32;
  assign sbox[8'ha2] = 8'h3a;
  assign sbox[8'ha3] = 8'h0a;
  assign sbox[8'ha4] = 8'h49;
  assign sbox[8'ha5] = 8'h06;
  assign sbox[8'ha6] = 8'h24;
  assign sbox[8'ha7] = 8'h5c;
  assign sbox[8'ha8] = 8'hc2;
  assign sbox[8'ha9] = 8'hd3;
  assign sbox[8'haa] = 8'hac;
  assign sbox[8'hab] = 8'h62;
  assign sbox[8'hac] = 8'h91;
  assign sbox[8'had] = 8'h95;
  assign sbox[8'hae] = 8'he4;
  assign sbox[8'haf] = 8'h79;
  assign sbox[8'hb0] = 8'he7;
  assign sbox[8'hb1] = 8'hc8;
  assign sbox[8'hb2] = 8'h37;
  assign sbox[8'hb3] = 8'h6d;
  assign sbox[8'hb4] = 8'h8d;
  assign sbox[8'hb5] = 8'hd5;
  assign sbox[8'hb6] = 8'h4e;
  assign sbox[8'hb7] = 8'ha9;
  assign sbox[8'hb8] = 8'h6c;
  assign sbox[8'hb9] = 8'h56;
  assign sbox[8'hba] = 8'hf4;
  assign sbox[8'hbb] = 8'hea;
  assign sbox[8'hbc] = 8'h65;
  assign sbox[8'hbd] = 8'h7a;
  assign sbox[8'hbe] = 8'hae;
  assign sbox[8'hbf] = 8'h08;
  assign sbox[8'hc0] = 8'hba;
  assign sbox[8'hc1] = 8'h78;
  assign sbox[8'hc2] = 8'h25;
  assign sbox[8'hc3] = 8'h2e;
  assign sbox[8'hc4] = 8'h1c;
  assign sbox[8'hc5] = 8'ha6;
  assign sbox[8'hc6] = 8'hb4;
  assign sbox[8'hc7] = 8'hc6;
  assign sbox[8'hc8] = 8'he8;
  assign sbox[8'hc9] = 8'hdd;
  assign sbox[8'hca] = 8'h74;
  assign sbox[8'hcb] = 8'h1f;
  assign sbox[8'hcc] = 8'h4b;
  assign sbox[8'hcd] = 8'hbd;
  assign sbox[8'hce] = 8'h8b;
  assign sbox[8'hcf] = 8'h8a;
  assign sbox[8'hd0] = 8'h70;
  assign sbox[8'hd1] = 8'h3e;
  assign sbox[8'hd2] = 8'hb5;
  assign sbox[8'hd3] = 8'h66;
  assign sbox[8'hd4] = 8'h48;
  assign sbox[8'hd5] = 8'h03;
  assign sbox[8'hd6] = 8'hf6;
  assign sbox[8'hd7] = 8'h0e;
  assign sbox[8'hd8] = 8'h61;
  assign sbox[8'hd9] = 8'h35;
  assign sbox[8'hda] = 8'h57;
  assign sbox[8'hdb] = 8'hb9;
  assign sbox[8'hdc] = 8'h86;
  assign sbox[8'hdd] = 8'hc1;
  assign sbox[8'hde] = 8'h1d;
  assign sbox[8'hdf] = 8'h9e;
  assign sbox[8'he0] = 8'he1;
  assign sbox[8'he1] = 8'hf8;
  assign sbox[8'he2] = 8'h98;
  assign sbox[8'he3] = 8'h11;
  assign sbox[8'he4] = 8'h69;
  assign sbox[8'he5] = 8'hd9;
  assign sbox[8'he6] = 8'h8e;
  assign sbox[8'he7] = 8'h94;
  assign sbox[8'he8] = 8'h9b;
  assign sbox[8'he9] = 8'h1e;
  assign sbox[8'hea] = 8'h87;
  assign sbox[8'heb] = 8'he9;
  assign sbox[8'hec] = 8'hce;
  assign sbox[8'hed] = 8'h55;
  assign sbox[8'hee] = 8'h28;
  assign sbox[8'hef] = 8'hdf;
  assign sbox[8'hf0] = 8'h8c;
  assign sbox[8'hf1] = 8'ha1;
  assign sbox[8'hf2] = 8'h89;
  assign sbox[8'hf3] = 8'h0d;
  assign sbox[8'hf4] = 8'hbf;
  assign sbox[8'hf5] = 8'he6;
  assign sbox[8'hf6] = 8'h42;
  assign sbox[8'hf7] = 8'h68;
  assign sbox[8'hf8] = 8'h41;
  assign sbox[8'hf9] = 8'h99;
  assign sbox[8'hfa] = 8'h2d;
  assign sbox[8'hfb] = 8'h0f;
  assign sbox[8'hfc] = 8'hb0;
  assign sbox[8'hfd] = 8'h54;
  assign sbox[8'hfe] = 8'hbb;
  assign sbox[8'hff] = 8'h16;

endmodule // aes_sbox

module Inv_round
(
data, //state
key,//key
rndout//output
);

input[127:0]data;
input [127:0] key;
output wire [127:0]rndout;

wire [127:0] isb,isr,ik_add;

INV_Shift_Rows p5(.in(data),.out(isr));
sub_bytes_inv p6 (.in(isr),.out(isb));
assign ik_add = key ^ isb;
InvMixCol p7 (.data_in(ik_add),.data_out(rndout));

endmodule

module INV_Shift_Rows
(
input [127:0] in,
output wire [127:0] out
);


assign out[127:120] = in[127:120];
assign out[119:112] = in[23:16];
assign out[111:104] = in[47:40];
assign out[103:96] = in[71:64];

assign out[95:88] = in[95:88];
assign out[87:80] = in[119:112];
assign out[79:72] = in[15:8];
assign out[71:64] = in[39:32];

assign out[63:56] = in[63:56];
assign out[55:48] = in[87:80];
assign out[47:40] = in[111:104];
assign out[39:32] = in[7:0];

assign out[31:24] = in[31:24];
assign out[23:16] = in[55:48];
assign out[15:8] = in[79:72];
assign out[7:0] = in[103:96];

endmodule

module sub_bytes_inv (in, out);
input [127:0] in;
output wire [127:0] out;

aes_sbox_inv w0(in[127-:32], out[127-:32]);
aes_sbox_inv w1(in[95-:32], out[95-:32]);
aes_sbox_inv w2(in[63-:32], out[63-:32]);
aes_sbox_inv w3(in[31-:32], out[31-:32]);


endmodule

module aes_sbox_inv(
                    input wire  [31 : 0] sboxw,
                    output wire [31 : 0] new_sboxw
                   );


  //----------------------------------------------------------------
  // The inverse sbox array.
  //----------------------------------------------------------------
  wire [7 : 0] inv_sbox [0 : 255];


  //----------------------------------------------------------------
  // Four parallel muxes.
  //----------------------------------------------------------------
  assign new_sboxw[31 : 24] = inv_sbox[sboxw[31 : 24]];
  assign new_sboxw[23 : 16] = inv_sbox[sboxw[23 : 16]];
  assign new_sboxw[15 : 08] = inv_sbox[sboxw[15 : 08]];
  assign new_sboxw[07 : 00] = inv_sbox[sboxw[07 : 00]];


  //----------------------------------------------------------------
  // Creating the contents of the array.
  //----------------------------------------------------------------
  assign inv_sbox[8'h00] = 8'h52;
  assign inv_sbox[8'h01] = 8'h09;
  assign inv_sbox[8'h02] = 8'h6a;
  assign inv_sbox[8'h03] = 8'hd5;
  assign inv_sbox[8'h04] = 8'h30;
  assign inv_sbox[8'h05] = 8'h36;
  assign inv_sbox[8'h06] = 8'ha5;
  assign inv_sbox[8'h07] = 8'h38;
  assign inv_sbox[8'h08] = 8'hbf;
  assign inv_sbox[8'h09] = 8'h40;
  assign inv_sbox[8'h0a] = 8'ha3;
  assign inv_sbox[8'h0b] = 8'h9e;
  assign inv_sbox[8'h0c] = 8'h81;
  assign inv_sbox[8'h0d] = 8'hf3;
  assign inv_sbox[8'h0e] = 8'hd7;
  assign inv_sbox[8'h0f] = 8'hfb;
  assign inv_sbox[8'h10] = 8'h7c;
  assign inv_sbox[8'h11] = 8'he3;
  assign inv_sbox[8'h12] = 8'h39;
  assign inv_sbox[8'h13] = 8'h82;
  assign inv_sbox[8'h14] = 8'h9b;
  assign inv_sbox[8'h15] = 8'h2f;
  assign inv_sbox[8'h16] = 8'hff;
  assign inv_sbox[8'h17] = 8'h87;
  assign inv_sbox[8'h18] = 8'h34;
  assign inv_sbox[8'h19] = 8'h8e;
  assign inv_sbox[8'h1a] = 8'h43;
  assign inv_sbox[8'h1b] = 8'h44;
  assign inv_sbox[8'h1c] = 8'hc4;
  assign inv_sbox[8'h1d] = 8'hde;
  assign inv_sbox[8'h1e] = 8'he9;
  assign inv_sbox[8'h1f] = 8'hcb;
  assign inv_sbox[8'h20] = 8'h54;
  assign inv_sbox[8'h21] = 8'h7b;
  assign inv_sbox[8'h22] = 8'h94;
  assign inv_sbox[8'h23] = 8'h32;
  assign inv_sbox[8'h24] = 8'ha6;
  assign inv_sbox[8'h25] = 8'hc2;
  assign inv_sbox[8'h26] = 8'h23;
  assign inv_sbox[8'h27] = 8'h3d;
  assign inv_sbox[8'h28] = 8'hee;
  assign inv_sbox[8'h29] = 8'h4c;
  assign inv_sbox[8'h2a] = 8'h95;
  assign inv_sbox[8'h2b] = 8'h0b;
  assign inv_sbox[8'h2c] = 8'h42;
  assign inv_sbox[8'h2d] = 8'hfa;
  assign inv_sbox[8'h2e] = 8'hc3;
  assign inv_sbox[8'h2f] = 8'h4e;
  assign inv_sbox[8'h30] = 8'h08;
  assign inv_sbox[8'h31] = 8'h2e;
  assign inv_sbox[8'h32] = 8'ha1;
  assign inv_sbox[8'h33] = 8'h66;
  assign inv_sbox[8'h34] = 8'h28;
  assign inv_sbox[8'h35] = 8'hd9;
  assign inv_sbox[8'h36] = 8'h24;
  assign inv_sbox[8'h37] = 8'hb2;
  assign inv_sbox[8'h38] = 8'h76;
  assign inv_sbox[8'h39] = 8'h5b;
  assign inv_sbox[8'h3a] = 8'ha2;
  assign inv_sbox[8'h3b] = 8'h49;
  assign inv_sbox[8'h3c] = 8'h6d;
  assign inv_sbox[8'h3d] = 8'h8b;
  assign inv_sbox[8'h3e] = 8'hd1;
  assign inv_sbox[8'h3f] = 8'h25;
  assign inv_sbox[8'h40] = 8'h72;
  assign inv_sbox[8'h41] = 8'hf8;
  assign inv_sbox[8'h42] = 8'hf6;
  assign inv_sbox[8'h43] = 8'h64;
  assign inv_sbox[8'h44] = 8'h86;
  assign inv_sbox[8'h45] = 8'h68;
  assign inv_sbox[8'h46] = 8'h98;
  assign inv_sbox[8'h47] = 8'h16;
  assign inv_sbox[8'h48] = 8'hd4;
  assign inv_sbox[8'h49] = 8'ha4;
  assign inv_sbox[8'h4a] = 8'h5c;
  assign inv_sbox[8'h4b] = 8'hcc;
  assign inv_sbox[8'h4c] = 8'h5d;
  assign inv_sbox[8'h4d] = 8'h65;
  assign inv_sbox[8'h4e] = 8'hb6;
  assign inv_sbox[8'h4f] = 8'h92;
  assign inv_sbox[8'h50] = 8'h6c;
  assign inv_sbox[8'h51] = 8'h70;
  assign inv_sbox[8'h52] = 8'h48;
  assign inv_sbox[8'h53] = 8'h50;
  assign inv_sbox[8'h54] = 8'hfd;
  assign inv_sbox[8'h55] = 8'hed;
  assign inv_sbox[8'h56] = 8'hb9;
  assign inv_sbox[8'h57] = 8'hda;
  assign inv_sbox[8'h58] = 8'h5e;
  assign inv_sbox[8'h59] = 8'h15;
  assign inv_sbox[8'h5a] = 8'h46;
  assign inv_sbox[8'h5b] = 8'h57;
  assign inv_sbox[8'h5c] = 8'ha7;
  assign inv_sbox[8'h5d] = 8'h8d;
  assign inv_sbox[8'h5e] = 8'h9d;
  assign inv_sbox[8'h5f] = 8'h84;
  assign inv_sbox[8'h60] = 8'h90;
  assign inv_sbox[8'h61] = 8'hd8;
  assign inv_sbox[8'h62] = 8'hab;
  assign inv_sbox[8'h63] = 8'h00;
  assign inv_sbox[8'h64] = 8'h8c;
  assign inv_sbox[8'h65] = 8'hbc;
  assign inv_sbox[8'h66] = 8'hd3;
  assign inv_sbox[8'h67] = 8'h0a;
  assign inv_sbox[8'h68] = 8'hf7;
  assign inv_sbox[8'h69] = 8'he4;
  assign inv_sbox[8'h6a] = 8'h58;
  assign inv_sbox[8'h6b] = 8'h05;
  assign inv_sbox[8'h6c] = 8'hb8;
  assign inv_sbox[8'h6d] = 8'hb3;
  assign inv_sbox[8'h6e] = 8'h45;
  assign inv_sbox[8'h6f] = 8'h06;
  assign inv_sbox[8'h70] = 8'hd0;
  assign inv_sbox[8'h71] = 8'h2c;
  assign inv_sbox[8'h72] = 8'h1e;
  assign inv_sbox[8'h73] = 8'h8f;
  assign inv_sbox[8'h74] = 8'hca;
  assign inv_sbox[8'h75] = 8'h3f;
  assign inv_sbox[8'h76] = 8'h0f;
  assign inv_sbox[8'h77] = 8'h02;
  assign inv_sbox[8'h78] = 8'hc1;
  assign inv_sbox[8'h79] = 8'haf;
  assign inv_sbox[8'h7a] = 8'hbd;
  assign inv_sbox[8'h7b] = 8'h03;
  assign inv_sbox[8'h7c] = 8'h01;
  assign inv_sbox[8'h7d] = 8'h13;
  assign inv_sbox[8'h7e] = 8'h8a;
  assign inv_sbox[8'h7f] = 8'h6b;
  assign inv_sbox[8'h80] = 8'h3a;
  assign inv_sbox[8'h81] = 8'h91;
  assign inv_sbox[8'h82] = 8'h11;
  assign inv_sbox[8'h83] = 8'h41;
  assign inv_sbox[8'h84] = 8'h4f;
  assign inv_sbox[8'h85] = 8'h67;
  assign inv_sbox[8'h86] = 8'hdc;
  assign inv_sbox[8'h87] = 8'hea;
  assign inv_sbox[8'h88] = 8'h97;
  assign inv_sbox[8'h89] = 8'hf2;
  assign inv_sbox[8'h8a] = 8'hcf;
  assign inv_sbox[8'h8b] = 8'hce;
  assign inv_sbox[8'h8c] = 8'hf0;
  assign inv_sbox[8'h8d] = 8'hb4;
  assign inv_sbox[8'h8e] = 8'he6;
  assign inv_sbox[8'h8f] = 8'h73;
  assign inv_sbox[8'h90] = 8'h96;
  assign inv_sbox[8'h91] = 8'hac;
  assign inv_sbox[8'h92] = 8'h74;
  assign inv_sbox[8'h93] = 8'h22;
  assign inv_sbox[8'h94] = 8'he7;
  assign inv_sbox[8'h95] = 8'had;
  assign inv_sbox[8'h96] = 8'h35;
  assign inv_sbox[8'h97] = 8'h85;
  assign inv_sbox[8'h98] = 8'he2;
  assign inv_sbox[8'h99] = 8'hf9;
  assign inv_sbox[8'h9a] = 8'h37;
  assign inv_sbox[8'h9b] = 8'he8;
  assign inv_sbox[8'h9c] = 8'h1c;
  assign inv_sbox[8'h9d] = 8'h75;
  assign inv_sbox[8'h9e] = 8'hdf;
  assign inv_sbox[8'h9f] = 8'h6e;
  assign inv_sbox[8'ha0] = 8'h47;
  assign inv_sbox[8'ha1] = 8'hf1;
  assign inv_sbox[8'ha2] = 8'h1a;
  assign inv_sbox[8'ha3] = 8'h71;
  assign inv_sbox[8'ha4] = 8'h1d;
  assign inv_sbox[8'ha5] = 8'h29;
  assign inv_sbox[8'ha6] = 8'hc5;
  assign inv_sbox[8'ha7] = 8'h89;
  assign inv_sbox[8'ha8] = 8'h6f;
  assign inv_sbox[8'ha9] = 8'hb7;
  assign inv_sbox[8'haa] = 8'h62;
  assign inv_sbox[8'hab] = 8'h0e;
  assign inv_sbox[8'hac] = 8'haa;
  assign inv_sbox[8'had] = 8'h18;
  assign inv_sbox[8'hae] = 8'hbe;
  assign inv_sbox[8'haf] = 8'h1b;
  assign inv_sbox[8'hb0] = 8'hfc;
  assign inv_sbox[8'hb1] = 8'h56;
  assign inv_sbox[8'hb2] = 8'h3e;
  assign inv_sbox[8'hb3] = 8'h4b;
  assign inv_sbox[8'hb4] = 8'hc6;
  assign inv_sbox[8'hb5] = 8'hd2;
  assign inv_sbox[8'hb6] = 8'h79;
  assign inv_sbox[8'hb7] = 8'h20;
  assign inv_sbox[8'hb8] = 8'h9a;
  assign inv_sbox[8'hb9] = 8'hdb;
  assign inv_sbox[8'hba] = 8'hc0;
  assign inv_sbox[8'hbb] = 8'hfe;
  assign inv_sbox[8'hbc] = 8'h78;
  assign inv_sbox[8'hbd] = 8'hcd;
  assign inv_sbox[8'hbe] = 8'h5a;
  assign inv_sbox[8'hbf] = 8'hf4;
  assign inv_sbox[8'hc0] = 8'h1f;
  assign inv_sbox[8'hc1] = 8'hdd;
  assign inv_sbox[8'hc2] = 8'ha8;
  assign inv_sbox[8'hc3] = 8'h33;
  assign inv_sbox[8'hc4] = 8'h88;
  assign inv_sbox[8'hc5] = 8'h07;
  assign inv_sbox[8'hc6] = 8'hc7;
  assign inv_sbox[8'hc7] = 8'h31;
  assign inv_sbox[8'hc8] = 8'hb1;
  assign inv_sbox[8'hc9] = 8'h12;
  assign inv_sbox[8'hca] = 8'h10;
  assign inv_sbox[8'hcb] = 8'h59;
  assign inv_sbox[8'hcc] = 8'h27;
  assign inv_sbox[8'hcd] = 8'h80;
  assign inv_sbox[8'hce] = 8'hec;
  assign inv_sbox[8'hcf] = 8'h5f;
  assign inv_sbox[8'hd0] = 8'h60;
  assign inv_sbox[8'hd1] = 8'h51;
  assign inv_sbox[8'hd2] = 8'h7f;
  assign inv_sbox[8'hd3] = 8'ha9;
  assign inv_sbox[8'hd4] = 8'h19;
  assign inv_sbox[8'hd5] = 8'hb5;
  assign inv_sbox[8'hd6] = 8'h4a;
  assign inv_sbox[8'hd7] = 8'h0d;
  assign inv_sbox[8'hd8] = 8'h2d;
  assign inv_sbox[8'hd9] = 8'he5;
  assign inv_sbox[8'hda] = 8'h7a;
  assign inv_sbox[8'hdb] = 8'h9f;
  assign inv_sbox[8'hdc] = 8'h93;
  assign inv_sbox[8'hdd] = 8'hc9;
  assign inv_sbox[8'hde] = 8'h9c;
  assign inv_sbox[8'hdf] = 8'hef;
  assign inv_sbox[8'he0] = 8'ha0;
  assign inv_sbox[8'he1] = 8'he0;
  assign inv_sbox[8'he2] = 8'h3b;
  assign inv_sbox[8'he3] = 8'h4d;
  assign inv_sbox[8'he4] = 8'hae;
  assign inv_sbox[8'he5] = 8'h2a;
  assign inv_sbox[8'he6] = 8'hf5;
  assign inv_sbox[8'he7] = 8'hb0;
  assign inv_sbox[8'he8] = 8'hc8;
  assign inv_sbox[8'he9] = 8'heb;
  assign inv_sbox[8'hea] = 8'hbb;
  assign inv_sbox[8'heb] = 8'h3c;
  assign inv_sbox[8'hec] = 8'h83;
  assign inv_sbox[8'hed] = 8'h53;
  assign inv_sbox[8'hee] = 8'h99;
  assign inv_sbox[8'hef] = 8'h61;
  assign inv_sbox[8'hf0] = 8'h17;
  assign inv_sbox[8'hf1] = 8'h2b;
  assign inv_sbox[8'hf2] = 8'h04;
  assign inv_sbox[8'hf3] = 8'h7e;
  assign inv_sbox[8'hf4] = 8'hba;
  assign inv_sbox[8'hf5] = 8'h77;
  assign inv_sbox[8'hf6] = 8'hd6;
  assign inv_sbox[8'hf7] = 8'h26;
  assign inv_sbox[8'hf8] = 8'he1;
  assign inv_sbox[8'hf9] = 8'h69;
  assign inv_sbox[8'hfa] = 8'h14;
  assign inv_sbox[8'hfb] = 8'h63;
  assign inv_sbox[8'hfc] = 8'h55;
  assign inv_sbox[8'hfd] = 8'h21;
  assign inv_sbox[8'hfe] = 8'h0c;
  assign inv_sbox[8'hff] = 8'h7d;

endmodule

module InvMixCol (data_in,data_out);

input [127:0] data_in;
output wire [127:0] data_out;

Inv_mx m0(data_in[127-:32],data_out[127-:32]);
Inv_mx m1(data_in[95-:32],data_out[95-:32]);
Inv_mx m2(data_in[63-:32],data_out[63-:32]);
Inv_mx m3(data_in[31-:32],data_out[31-:32]);


endmodule

module Inv_mx (
    data_in,data_out
);
    
input [31:0] data_in;
output wire [31:0] data_out;
wire [7:0] e0,e1,e2,e3, b0,b1,b2,b3, d0,d1,d2,d3, g0,g1,g2,g3;

mutli me0(8'h0e, data_in[31-:8], e0);
mutli me1(8'h0e, data_in[23-:8], e1);
mutli me2(8'h0e, data_in[15-:8], e2);
mutli me3(8'h0e, data_in[7-:8], e3);


mutli mb0( 8'h0b, data_in[31-:8], b0);
mutli mb1( 8'h0b, data_in[23-:8], b1);
mutli mb2( 8'h0b, data_in[15-:8], b2);
mutli mb3( 8'h0b, data_in[7-:8], b3);

mutli md0( 8'h0d, data_in[31-:8], d0);
mutli md1( 8'h0d, data_in[23-:8], d1);
mutli md2( 8'h0d, data_in[15-:8], d2);
mutli md3( 8'h0d, data_in[7-:8], d3);

mutli mg0( 8'h09, data_in[31-:8], g0);
mutli mg1( 8'h09, data_in[23-:8], g1);
mutli mg2( 8'h09, data_in[15-:8], g2);
mutli mg3( 8'h09, data_in[7-:8], g3);



assign data_out[31-:8] = e0 ^ b1 ^ d2 ^ g3;
assign data_out[23-:8] = g0 ^ e1 ^ b2 ^ d3;
assign data_out[15-:8] = d0 ^ g1 ^ e2 ^ b3;
assign data_out[7-:8]  = b0 ^ d1 ^ g2 ^ e3;

endmodule

module mutli(a,b,out);
input [7:0] a;
input [7:0] b;
output reg [7:0] out;
reg [7:0] a1;
reg [7:0] b1;
reg [7:0] carry;

integer i;

always @ (*) begin
    out = 8'b0;
    a1 = a;
    b1 = b;

    for(i = 0;i < 8;i = i + 1) begin
        if((b1 & 1) == 1) out = out ^ a1;   //add if rightmost b is 1
        b1 = b1 >> 1;                       //divide b by X except X    0

        carry = (a1 & 8'b1000_0000);          //check if LSB is 1

        a1 = a1 << 1;
        if(carry == 8'b1000_0000) a1 = a1 ^ 8'b00011011; //subtract if there's carry
    end

end

endmodule
