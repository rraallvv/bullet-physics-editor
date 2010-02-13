/*
 *  ExperimentalBulletWrapper.cpp
 *  OpenGLEditor
 *
 *  Created by Filip Kunc on 04/02/10.
 *  For license see LICENSE.TXT
 *
 */

#include "ExperimentalBulletWrapper.h"
#include "MarshalHelpers.h"
using namespace std;

namespace ManagedCpp
{
	ExperimentalBulletWrapper::ExperimentalBulletWrapper(String ^fileName)
	{
		string nativeFileName = NativeString(fileName);
		wrapper = new BulletWrapperHelper();
		wrapper->LoadFile(nativeFileName.c_str());
	}

	void ExperimentalBulletWrapper::StepSimulation(btScalar timeStep)
	{
		wrapper->dynamicsWorld->stepSimulation(timeStep);
	}

	#pragma region OpenGLManipulatingModel implementation

	void ExperimentalBulletWrapper::Draw(uint index, CocoaBool forSelection, ViewMode mode)
	{
		wrapper->Draw(index, !forSelection && this->IsSelected(index));
	}

	uint ExperimentalBulletWrapper::Count::get()
	{
		return (uint)wrapper->dynamicsWorld->getNumCollisionObjects();
	}

	CocoaBool ExperimentalBulletWrapper::IsSelected(uint index)
	{
		return wrapper->selection->at(index);
	}

	void ExperimentalBulletWrapper::SetSelected(CocoaBool selected, uint index)
	{
		wrapper->selection->at(index) = selected;
	}

	void ExperimentalBulletWrapper::CloneSelected() { }
	void ExperimentalBulletWrapper::RemoveSelected() { }	
	void ExperimentalBulletWrapper::WillSelect() { }
	void ExperimentalBulletWrapper::DidSelect() { }

	Vector3D ExperimentalBulletWrapper::GetPosition(uint index)
	{
		return wrapper->GetPosition(index);
	}

	Quaternion ExperimentalBulletWrapper::GetRotation(uint index)
	{
		return wrapper->GetRotation(index);
	}

	Vector3D ExperimentalBulletWrapper::GetScale(uint index)
	{
		return Vector3D(1, 1, 1); // ignored
	}

	void ExperimentalBulletWrapper::SetPosition(Vector3D position, uint index)
	{
		wrapper->SetPosition(position, index);
	}

	void ExperimentalBulletWrapper::SetRotation(Quaternion rotation, uint index)
	{
		wrapper->SetRotation(rotation, index);
	}

	void ExperimentalBulletWrapper::SetScale(Vector3D scale, uint index)
	{
		// ignored
	}

	void ExperimentalBulletWrapper::MoveBy(Vector3D offset, uint index)
	{
		Vector3D position = this->GetPosition(index);
		position += offset;
		this->SetPosition(position, index);
	}

	void ExperimentalBulletWrapper::RotateBy(Quaternion offset, uint index)
	{
		Quaternion rotation = this->GetRotation(index);
		rotation = offset * rotation;
		this->SetRotation(rotation, index);
	}

	void ExperimentalBulletWrapper::ScaleBy(Vector3D offset, uint index)
	{
		// ignored
	}

	#pragma endregion
}