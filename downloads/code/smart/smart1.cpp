#include <iostream>
using namespace std;
#include <tr1/memory>
using namespace std::tr1;

struct SharedClass
{
   SharedClass();
   ~SharedClass();

};

SharedClass::SharedClass()
{
   cout << "SharedClass ctor:" << this << endl;
}

SharedClass::~SharedClass()
{
   cout << "SharedClass dtor:" << this << endl;
}

struct ContainerClass
{
   ContainerClass();
   ~ContainerClass();

	shared_ptr<SharedClass> getShared();

	shared_ptr<SharedClass> memberPtr;

	static shared_ptr<SharedClass>  masterPtr;
};

shared_ptr<SharedClass>   ContainerClass::masterPtr;

shared_ptr<SharedClass> ContainerClass::getShared()
{
   if (!masterPtr.get()) {
      masterPtr = shared_ptr<SharedClass>(new SharedClass());
   }

   return masterPtr;
}


ContainerClass::ContainerClass()
{
   cout << "ContainerClass ctor:" << this << endl;
   cout << "\tbefore\tcopy: " << memberPtr.use_count() << "\t" << "master: " << masterPtr.use_count() << endl;

   memberPtr = getShared();

   cout << "\tafter\tcopy: " << memberPtr.use_count() << "\t" << "master: " << masterPtr.use_count() << endl;
   cout << endl;
}

ContainerClass::~ContainerClass()
{
   cout << "ContainerClass dtor:" << this << endl;
   cout << "\tbefore\tcopy: " << memberPtr.use_count() << "\t" << "master: " << masterPtr.use_count() << endl;

   cout << endl;
}

int main(int argc, char** argv)
{
   cout << "Entering main" << endl;

   ContainerClass* pClass1 = new ContainerClass();
   ContainerClass* pClass2 = new ContainerClass();

   delete pClass1;
   delete pClass2;

   ContainerClass* pClass3 = new ContainerClass();
   delete pClass3;

   cout << "Exiting main" << endl;
}
