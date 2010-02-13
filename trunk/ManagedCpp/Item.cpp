/*
 *  Item.cpp
 *  OpenGLEditor
 *
 *  Created by Filip Kunc on 10/23/09.
 *  For license see LICENSE.TXT
 *
 */

#include "Item.h"

namespace ManagedCpp
{
	Item::Item()
	{
		position = new Vector3D();
		rotation = new Quaternion();
		scale = new Vector3D(1, 1, 1);
		mesh = gcnew Mesh();
		selected = NO;
	}
	
	Item::Item(Vector3D aPosition, Quaternion aRotation, Vector3D aScale)
	{
		position = new Vector3D(aPosition);
		rotation = new Quaternion(aRotation);
		scale = new Vector3D(aScale);
		mesh = gcnew Mesh();
		selected = NO;
	}

	Item::~Item()
	{
		delete position;
		delete rotation;
		delete scale;
		mesh = nullptr;
	}

	Vector3D Item::Position::get()
	{
		return *position;
	}

	void Item::Position::set(Vector3D value)
	{
		*position = value;
	}

	Quaternion Item::Rotation::get()
	{
		return *rotation;
	}

	void Item::Rotation::set(Quaternion value)
	{
		*rotation = value;
	}

	Vector3D Item::Scale::get()
	{
		return *scale;
	}

	void Item::Scale::set(Vector3D value)
	{
		*scale = value;
	}

	CocoaBool Item::Selected::get()
	{
		return selected;
	}

	void Item::Selected::set(CocoaBool value)
	{
		selected = value;
	}
	
	void Item::Draw(ViewMode mode)
	{
		glPushMatrix();
		glTranslatef(position->x, position->y, position->z);
		Matrix4x4 rotationMatrix;
		rotation->ToMatrix(rotationMatrix);
		glMultMatrixf(rotationMatrix);
		if (mode == ViewMode::ViewModeSolid)
			mesh->Draw(*scale, selected);
		else
			mesh->DrawWire(*scale, selected);
		glPopMatrix();
	}
	
	void Item::MoveBy(Vector3D offset)
	{
		*position += offset;
	}
	
	void Item::RotateBy(Quaternion offset)
	{
		*rotation = offset * *rotation;
	}
	
	void Item::ScaleBy(Vector3D offset)
	{
		*scale += offset;
	}
	
	Item ^Item::Clone()
	{
		Item ^newItem = gcnew Item(this->Position, this->Rotation, this->Scale);

		newItem->mesh->Merge(this->mesh);
		newItem->selected = NO;
		this->selected = YES;
		
		return newItem;
	}

	Mesh ^Item::GetMesh()
	{
		return mesh;
	}

	void Item::Decode(ifstream *fin)
	{
		fin->read((char *)position, sizeof(Vector3D));
		fin->read((char *)rotation, sizeof(Quaternion));
		fin->read((char *)scale, sizeof(Vector3D));
		CocoaBool stackSelected = selected;
		fin->read((char *)&stackSelected, sizeof(CocoaBool));

		mesh->Decode(fin);
	}

	void Item::Encode(ofstream *fout)
	{
		fout->write((char *)position, sizeof(Vector3D));
		fout->write((char *)rotation, sizeof(Quaternion));
		fout->write((char *)scale, sizeof(Vector3D));
		CocoaBool stackSelected = selected;
		fout->write((char *)&stackSelected, sizeof(CocoaBool));

		mesh->Encode(fout);
	}
}
