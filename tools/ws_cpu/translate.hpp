#include <iostream>
#include <cstring>
#include <cstdio>
#include <algorithm>
#include <cmath>
#include <vector>
#include <queue>
#include <set>

using namespace std;
typedef unsigned int uint;
const int MAXN = 15; 
struct Instructions{
	uint opc=0,rd=0,func3=0,rs1=0,rs2=0,func7=0,imm=0;
	int tp=0;
	uint code,pc;
	int end=0;
};

Instructions __translate(uint t,uint O) {
	
	uint tmp=1<<7;
	tmp--;
	Instructions res;res.opc=tmp&t;
	res.code=t;
	res.pc=O;
	if(t==0x0ff00513) {res.end=1;return res;}
	if((tmp&t)==3||((tmp&t)==19)||res.opc==103) {//I:
		for(uint i=7;i<=11;++i) {
			if(((uint)1<<i)&t) res.rd+=1<<i;
		}
		res.rd>>=7;
		for(uint i=12;i<=14;++i) {
			if(((uint)1<<i)&t) res.func3+=1<<i;
		}
		res.func3>>=12;
		for(uint i=15;i<=19;++i) {
			if(((uint)1<<i)&t) res.rs1+=1<<i;
		}
		res.rs1>>=15;
		for(uint i=20;i<=31;++i) {
			if(((uint)1<<i)&t) res.imm+=1<<i;
		}
		res.imm>>=20;
		if(res.imm&(1<<11))
		for(uint i=12;i<=31;++i) {
			res.imm+=((uint)1<<i);
		}
		if(res.opc==3) {
			if(res.func3==0) res.tp=0;//lb
			if(res.func3==1) res.tp=1;//lh
			if(res.func3==2) res.tp=2;//lw
			if(res.func3==4) res.tp=3;//lbu
			if(res.func3==5) res.tp=4;//lhu
		}
		if(res.opc==19) {
			if(res.func3==0) res.tp=9;//addi
			if(res.func3==4) res.tp=14;//xori 
			if(res.func3==6) res.tp=16;//ori
			if(res.func3==7) res.tp=18;//andi
			if(res.func3==1) res.tp=20;//slli
			if(res.func3==5) 
			{
				if(res.imm<64)
				res.tp=22;//srli 
				else res.tp=24;//srai
			}
			if(res.func3==2) {
				res.tp=26;//slti
			}
			if(res.func3==3) res.tp=28;//sltiu
		}
		if(res.opc==103) {
			if(res.func3==0) res.tp=36;//jalr
		}
		return res;
	} 
	if(res.opc==35) //S:
	{
		for(uint i=7;i<=11;++i) {
			if(((uint)1<<i)&t) res.imm+=1<<i;
		}
		res.imm>>=7;
		for(uint i=12;i<=14;++i) {
			if(((uint)1<<i)&t) res.func3+=1<<i;
		}
		res.func3>>=12;
		for(uint i=15;i<=19;++i) {
			if(((uint)1<<i)&t) res.rs1+=1<<i;
		}
		res.rs1>>=15;
		for(uint i=20;i<=24;++i) {
			if(((uint)1<<i)&t) res.rs2+=1<<i;
		}
		res.rs2>>=20;
		uint temp=0;
		for(uint i=25;i<=31;++i) {
			if(((uint)1<<i)&t) temp+=1<<i;
		}
		temp>>=25;
		temp<<=5;
		res.imm+=temp;
		if(res.imm&(1<<11))
		for(uint i=12;i<=31;++i) {
			res.imm+=((uint)1<<i);
		}
		if(res.opc==35) {
			if(res.func3==0) res.tp=5;//sb
			if(res.func3==1) res.tp=6;//sh
			if(res.func3==2) res.tp=7;//sw			 
		}
		return res;
	}
	if(res.opc==51) //R:
	{
		for(uint i=7;i<=11;++i) {
			if(((uint)1<<i)&t) res.rd+=1<<i;
		}
		res.rd>>=7;
		for(uint i=12;i<=14;++i) {
			if(((uint)1<<i)&t) res.func3+=1<<i;
		}
		res.func3>>=12;
		for(uint i=15;i<=19;++i) {
			if(((uint)1<<i)&t) res.rs1+=1<<i;
		}
		res.rs1>>=15;
		for(uint i=20;i<=24;++i) {
			if(((uint)1<<i)&t) res.rs2+=1<<i;
		}
		res.rs2>>=20;
		for(uint i=25;i<=31;++i) {
			if(((uint)1<<i)&t) res.func7+=1<<i;
		}
		res.func7>>=25;
		if(res.opc==51) {
			if(res.func3==0)
			{
				if(res.func7==0) res.tp=8;//add
				if(res.func7==32) res.tp=10;//sub
			}
			if(res.func3==4) {
				if(res.func7==0) res.tp=13;//xor
				
			}
			if(res.func3==6) {
				if(res.func7==0) res.tp=15;//or
			}
			if(res.func3==7) {
				if(res.func7==0) res.tp=17;//and
			}
			if(res.func3==1) {
				if(res.func7==0) res.tp=19;//sll
			}
			if(res.func3==5) {
				if(res.func7==0) res.tp=21;//srl
				if(res.func7==32) res.tp=23;//sra
			}
			if(res.func3==2) {
				if(res.func7==0) res.tp=25;//slt
			}
			if(res.func3==3) {
				if(res.func7==0) res.tp=27;//sltu
			}
		}
		return res;
	}
	if(res.opc==55||res.opc==23) {//U:
		for(uint i=7;i<=11;++i) {
			if(((uint)1<<i)&t) res.rd+=1<<i;
		}
		res.rd>>=7;
		for(uint i=12;i<=31;++i) {
			if(((uint)1<<i)&t) res.imm+=1<<i;
		}
		
		if(res.opc==55) {
			res.tp=11;//lui;
		}
		if(res.opc==23) res.tp=12;//auipc
		return res;
	}
	if(res.opc==99) {
		if((1<<7)&t) res.imm+=1<<11;
		uint tmp=0;
		for(uint i=8;i<=11;++i) if((1<<i)&t) tmp+=1<<i;
		tmp>>=7;
		res.imm+=tmp;
		tmp=0;
		for(uint i=25;i<=30;++i) if((1<<i)&t) tmp+=1<<i;
		tmp>>=25;
		tmp<<=5;
		res.imm+=tmp;
		if(((uint)1<<31)&t) {
			for(uint i=12;i<=31;++i){
				res.imm+=(uint)1<<i; 
			}
		}
//		if(res.code==4261844707u) {
//			cerr<<"WWWWWWWWWWW\n";
//			cerr<<res.imm<<"\n";
//		}
		for(uint i=15;i<=19;++i) {
			if(((uint)1<<i)&t) res.rs1+=1<<i;
		}
		res.rs1>>=15;
		for(uint i=20;i<=24;++i) {
			if(((uint)1<<i)&t) res.rs2+=1<<i;
		}
		res.rs2>>=20;
		for(uint i=12;i<=14;++i) {
			if(((uint)1<<i)&t) res.func3+=1<<i;
		}
		res.func3>>=12;
		if(res.opc==99)
		{
			if(res.func3==0) {
				res.tp=29;//beq
			}
			if(res.func3==1) {
				res.tp=30;//bne
			}
			if(res.func3==4) {
				res.tp=31;//blt
			}
			if(res.func3==5) {
				res.tp=32;//bge
			}
			if(res.func3==6) {
				res.tp=33;//bltu
			}
			if(res.func3==7) {
				res.tp=34;//bgeu
			}
		}
		return res;
	}
	if(res.opc==111) {
		for(uint i=7;i<=11;++i) {
			if(((uint)1<<i)&t) res.rd+=1<<i;
		}
		res.rd>>=7;
		for(uint i=12;i<=19;++i) {
			if(((uint)1<<i)&t) res.imm+=1<<i;
		}
		if((1<<20)&t) res.imm+=1<<11;
		for(uint i=21;i<=30;++i) {
			if(((uint)1<<i)&t) res.imm+=1<<(i-20);
		}
		if(((uint)1<<31)&t) {
			for(uint i=20;i<=31;++i) {
				res.imm+=(uint)1<<i;
			}
		}
		res.tp=35;//jal
		return res;
	}
	return res;
}
