## CPU 设计方案



**调试核心：精准中断于错误指令（靠对拍实现）和模拟器没有区别，但这次要更手术刀** 



#### 得分分配

- 五级流水 60 pts
- 缓存 / 缓存一致性协议 40 pts
- 特权指令集 20 pts
- 异常处理——《自己动手写CPU》

**能超前调出来，不介意多花一周 transfer 到 Tomasulo** 



#### 阶段

- 全 stall 型五级流水
- cache 型五级流水



#### 特殊要点

- 启动保护：所有的模块等待 testbench 开始运行时延一会再开机（有没有延时的必要？）

  rst_in == 1 || rdy_in == 0 全部清空，保护电路各个模块（但 clk_in 是唯一触发信号）

- 内存保护：默认为读状态（mem_wr=0）

- 读保护：取值时用寄存器接住 mem_din

- 写保护：将写头与寄存器相连，先寻址并给寄存器赋值后再改 mem_wr

- 流程保护：尽可能保证传给下一个 layer 的数据是正确的

- 原则上只有五个部件是时序逻辑模块，其他的都是组合逻辑模块

- 严格按照五级流水图来

- 实现 debug_show



**一个 clk 不是一个 cycle ，全部采用上升沿工作+非阻塞赋值传给后面**

**即完全按照 clk 作为工作周期，非 clk 上升沿绝不工作** 



#### 文件结构（src）

- 基础组合电路：IF / ID / EX / MEM / WB + .v

- 基础时序电路：IF_ID / ID_EX / EX_MEM / MEM_WB + .v

  或者干脆用 layer.v 例化 5 次

- constant.v 记录所有常数

- regfile.v 通用寄存器

- pc_reg.v pc 寄存器

- controller.v 全局控制包括 stall 在内的流水线运行

  控制块内采用多个 always 块控制所有的运行

- testbench 设计思路

  ~~~verilog
  module tb ;
      
      reg in ;
      wire out ;
      reg clk = 0 ;
      reg cnt = 0 ;
      
      A a(
          .in(in) ,
          .out(out)
      )
      always begin
      	repeat(100) begin
          	# 1
         		clk = ~clk ;
              cnt++ ;
     	 	end
      end
      
      always@(posedge clk) begin
          case(cnt) begin
              1 : 
              2 :
              3 :
              ...
          end
      end
      
      
  ~~~

  

  



#### 问题

- regfile 结构冲突（采用双端口解决）

- 上升沿模块工作，下降沿夹层工作

- 没有 Icache 的状态下，一个周期读两次内存（MEM只有一个端口）解决方法是让 IF 等

  （EX_MEM）为 ctrl 发信号，让 IF stall 住不允许读

- 刷新看 rst 和 rdy 通过每个时钟周期自检

- 和模拟器相同，每个答案层都有 status 设定

- IF 是否需要暂存指令 发送请求后不认为可以立刻收到 inst，所以是否需要缓存一条 inst 和 pc

  甚至读四次还需要四个周期，有问题

  竟然是将现成的 inst 作为转手直接送到 output 去？

- mem_ctrl 更应该是组合逻辑？

- 给出信号要及时，收信号要等待（发信号不存在结构冲突时要保证实时传输的有效性）

- 在 ID 处如果读到了错误的信号，那么这个周期 IF 是不会更新的（ ctrl 控制 ）但等到 data hazard 结束后如何让各组合模块重启？**用 stall_in 在 if 中作为敏感列表控制** 

- ctrl 的核心是组合逻辑，上升沿执行完同时激发 ctrl



