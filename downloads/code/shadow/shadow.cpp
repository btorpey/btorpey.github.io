#include <memory>
using namespace std;

class D
{
public:   
   void Init()
   {
   }
};

class C 
{
public:   
   C()
   {
      D* _pD = new D;
      _pD->Init();
   }
   
   ~C()
   {
      delete _pD;
   }
   
private:
   D* _pD;   
};



int main(int , char** )
{

   C c;

   return 0;
}