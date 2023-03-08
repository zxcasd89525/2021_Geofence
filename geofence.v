module geofence ( clk,reset,X,Y,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
output reg valid;
output reg is_inside;

//---------------------coding---------------------
reg [2:0] n_state,c_state;
reg [2:0] cnt;
wire [3:0] index_0,index_1,index_2;

reg [19:0] obj;
reg [19:0] fence[0:5];
reg signed [20:0] tempA;
wire signed [20:0] tempB,tempC;
reg signed [10:0] tempD;
reg [3:0] cal_flag;
reg sort_flag;


parameter IDLE       = 3'd0,
          OBJ_XY     = 3'd1,
          FENCE_XY   = 3'd2,
          CAL_OP     = 3'd3,
          FENCE_SORT = 3'd4,
          CAL_INSIDE = 3'd5,
          OUTPUT     = 3'd6
;

//c_state
always @(posedge clk or posedge reset) begin
    if(reset) c_state <= OBJ_XY;
    else c_state <= n_state;
end

//n_state
always @(*) begin
    case (c_state)
        IDLE       : n_state = OBJ_XY;
        OBJ_XY     : n_state = FENCE_XY;
        FENCE_XY   : n_state = (cnt == 3'd5) ? CAL_OP : c_state;
        CAL_OP     : n_state = (cal_flag == 4'd13 ) ? FENCE_SORT : c_state;
        FENCE_SORT : n_state = (cnt == 3'd3 && sort_flag == 1'b0) ? CAL_INSIDE : CAL_OP;
        CAL_INSIDE : n_state = (cnt == 3'd5) ? OUTPUT : c_state;
        OUTPUT     : n_state = OBJ_XY;
        default    : n_state = c_state; 
    endcase
end

//obj
always @(posedge clk or posedge reset) begin
    if(reset)begin
        obj <= 20'd0;
    end
    else if(c_state == OBJ_XY)begin
        obj[19:10] <= X;
        obj[9:0] <= Y;
    end
    else obj <= obj;
end
//cal_flag
always @(posedge clk or posedge reset) begin
    if(reset) cal_flag <= 4'd0;
    else if(c_state == CAL_INSIDE && cal_flag == 4'd14) cal_flag <= 4'd0;
    else if(c_state == CAL_OP || c_state == CAL_INSIDE) cal_flag <= cal_flag + 4'd1;
    else cal_flag <= 4'd0;
end

assign index_0 = cnt;
assign index_1 = cnt+3'd1;
assign index_2 = cnt+3'd2;
assign tempB = (cal_flag == 4'd6) ? tempA : tempB;
assign tempC = (cal_flag == 4'd2 || cal_flag == 4'd9 || cal_flag == 4'd13) ? tempA : tempC;
// Ax = (fence[(cnt+1)<<1] - fence[0])
// Ay = (fence[((cnt+1)<<1)+1] - fence[1])
// Bx = (fence[(cnt+2)<<1] - fence[0])
// By = (fence[((cnt+2)<<1)+1] - fence[1])
//tempA & tempD

always @(posedge clk or posedge reset) begin
    if(reset)begin
        tempA <= 21'd0;
        tempD <= 11'd0;
    end
    else if(cal_flag == 4'd0)begin
        if(c_state == CAL_OP)begin
            //Ax
            tempA <= fence[index_1][19:10];
            tempD <= fence[0][19:10];
        end
        else if(c_state == CAL_INSIDE)begin
            //Ax
            tempA <= fence[index_0][19:10];
            tempD <= obj[19:10];
        end
    end
    else if(cal_flag == 4'd1 || cal_flag == 4'd4 || cal_flag == 4'd8 || cal_flag == 4'd11) tempA <= tempA - tempD;
    else if(cal_flag == 4'd3)begin
        if(c_state == CAL_OP)begin
            //By
            tempA <= fence[index_2][9:0];
            tempD <= fence[0][9:0];
        end
        else if(c_state == CAL_INSIDE)begin
            //By
            tempA <= fence[index_1][9:0];
            tempD <= obj[9:0];
        end
    end
    else if(cal_flag == 4'd5 || cal_flag == 4'd12) tempA <= tempA * tempC;
    else if(cal_flag == 4'd7)begin
        if(c_state == CAL_OP)begin
            //Bx
            tempA <= fence[index_2][19:10];
            tempD <= fence[0][19:10];
        end
        else if(c_state == CAL_INSIDE)begin
            //Bx
            tempA <= fence[index_1][19:10];
            tempD <= obj[19:10];
        end
    end
    else if(cal_flag == 4'd10)begin
        if(c_state == CAL_OP)begin
            //Ay
            tempA <= fence[index_1][9:0];
            tempD <= fence[0][9:0];
        end
        else if(c_state == CAL_INSIDE)begin
            //Ay
            tempA <= fence[index_0][9:0];
            tempD <= obj[9:0];
        end
    end
    else begin
        tempA <= tempA;
        tempD <= tempD;
    end
end
//fence 
always @(posedge clk or posedge reset) begin
    if(reset)begin
        fence[0] <= 20'd0;
        fence[1] <= 20'd0;
        fence[2] <= 20'd0;
        fence[3] <= 20'd0;
        fence[4] <= 20'd0;
        fence[5] <= 20'd0;
    end
    else if(c_state == FENCE_XY)begin
        fence[index_0][19:10] <= X;
        fence[index_0][9:0] <= Y;
    end
    else if(c_state == FENCE_SORT && tempB > tempC)begin
        fence[index_1][19:10] <= fence[index_2][19:10]; // Ax <= Bx
        fence[index_2][19:10] <= fence[index_1][19:10]; // Bx <= Ax
        fence[index_1][9:0]   <= fence[index_2][9:0]; // Ay <= By
        fence[index_2][9:0]   <= fence[index_1][9:0]; // By <= Ay
    end
    else begin
        fence[0] <= fence[0];
        fence[1] <= fence[1];
        fence[2] <= fence[2];
        fence[3] <= fence[3];
        fence[4] <= fence[4];
        fence[5] <= fence[5];
    end
end
//sort_flag
always @(posedge clk or posedge reset)begin
    if(reset)sort_flag <= 1'b0;
    else if(c_state == CAL_OP && cnt == 3'd0 && cal_flag == 4'd0) sort_flag <= 1'b0;
    else if(c_state == FENCE_SORT && tempB > tempC) sort_flag <= 1'b1;
    else sort_flag <= sort_flag;
end
//cnt
always @(posedge clk or posedge reset) begin
    if(reset) cnt <= 3'd0;
    else if((c_state == FENCE_XY && cnt < 3'd5) ||(c_state == FENCE_SORT && cnt < 3'd3) || (c_state == CAL_INSIDE && cal_flag == 4'd14)) cnt <= cnt + 3'd1;
    else if(c_state == CAL_OP ||(c_state == CAL_INSIDE && cal_flag < 4'd14)) cnt <= cnt;
    else cnt <= 3'd0;
end
//valid
always @(posedge clk or posedge reset) begin
    if(reset) valid <= 1'b0;
    else if(n_state == OUTPUT) valid <= 1'b1;
    else valid <= 1'b0;
end
//is_inside
always @(posedge clk or posedge reset) begin
    if(reset) is_inside <= 1'b1;
    else if(c_state == CAL_INSIDE)begin
        if(cal_flag == 4'd14 && tempB > tempC) is_inside <= 1'b0;
    end
    else if(n_state == OUTPUT) is_inside <= is_inside;
    else is_inside <= 1'b1;
end
endmodule