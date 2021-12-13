//#include<bits/stdc++.h>
//#include "translate.hpp"
//using namespace std;

struct ROB{
	bool ready=0;
	int tp=0;
	uint result=0;
	uint addr=0;
	uint offset=0;
	uint result2=0;
	uint code;
	uint pc;
	uint debuger;
	uint rs1=0,rs2=0;
	Instructions temp;
};
//const int MAXN=15;
class Reorder_Buffer{
	public:
	
	ROB queue[MAXN];
	int head=0,tail=0;
	Reorder_Buffer() {
		head=tail=0;
	}
	int get_nxt(int cur) {
		cur++;
		if(cur>=MAXN) cur-=MAXN;
		return cur;
	}
	void push_back(ROB tmp) {
		queue[tail]=tmp;
		tail=get_nxt(tail);
	}
	bool isempty() {
		return head==tail;
	}
	bool isfull() {
		return get_nxt(tail)==head;
	}
	ROB get_front() {return queue[head];}
	void pop_front() {
		head++;
		head%=MAXN;
	}
	void print() {
		cout<<"ROB_begin:\n";
		int tmp=head;
		while(tmp!=tail) {
			cout<<queue[tmp].code<<" ";
			tmp=get_nxt(tmp);
		}
		cout<<"\nROB_endl\n"; 
	}
};
