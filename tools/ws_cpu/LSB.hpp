struct LSB{
	
	uint idx;
	uint tp;
	uint addr=0,imm=0;
	int q=-1,q2=-1;
	uint v=0,v2=0;
	uint _commited=0,_round=3;
	uint code;
};
class Load_Store_Buffer{
	public:
	LSB queue[MAXN];
	int head=0,tail=0;
	Load_Store_Buffer() {
		head=tail=0;
	}
	int get_nxt(int cur) {
		cur++;
		cur%=MAXN;
		return cur;
	}
	void push_back(LSB tmp) {
		queue[tail]=tmp;
		tail=get_nxt(tail);
	}
	bool isempty() {
		return head==tail;
	}
	bool isfull() {
		return get_nxt(tail)==head;
	}
	LSB get_front() {return queue[head];}
	void pop_front() {
		head++;
		head%=MAXN;
	}
	void Update(uint idx,uint res) {
		int tmp=head;
		while(tmp!=tail) {
			if(queue[tmp].idx==idx&&queue[tmp].tp>4) queue[tmp]._commited=1;
			if(queue[tmp].q==(int)idx) queue[tmp].v=res,queue[tmp].q=-1;
			if(queue[tmp].q2==(int)idx) queue[tmp].v2=res,queue[tmp].q2=-1;
			tmp=get_nxt(tmp);
		}
	}
	void clear() {
		int tmp=head;
		while(tmp!=tail) {
			if(queue[tmp]._commited==0) {tail=tmp;break;} 
			tmp=get_nxt(tmp);
		}
	}
};
