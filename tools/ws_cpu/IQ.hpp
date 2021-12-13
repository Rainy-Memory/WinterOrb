//#ifndef
//#include<bits/stdc++.h>
//#include "translate.hpp"
//using namespace std;
//const int MAXN=15;
class Instructions_Queue{
	public:
	
	Instructions queue[MAXN];
	int head=0,tail=0;
	Instructions_Queue() {
		head=tail=0;
	}
	int get_nxt(int cur) {
		cur++;
		if(cur>=MAXN) cur-=MAXN;
		return cur;
	}
	void push_back(Instructions tmp) {
		queue[tail]=tmp;
		tail=get_nxt(tail);
	}
	bool isempty() {
		return head==tail;
	}
	bool isfull() {
		return get_nxt(tail)==head;
	}
	Instructions get_front() {return queue[head];}
	void pop_front() {
		head++;
		head%=MAXN;
	}
};
