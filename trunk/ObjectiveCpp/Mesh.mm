//
//  Mesh.m
//  OpenGLEditor
//
//  Created by Filip Kunc on 7/29/09.
//  For license see LICENSE.TXT
//

#import "Mesh.h"

static ShaderProgram *normalShader;
static ShaderProgram *flippedShader;

@implementation Mesh

@synthesize selectionMode;

+ (NSString *)descriptionOfMeshType:(enum MeshType)type
{
	switch (type)
	{
		case MeshTypeCube:
			return @"Cube";
		case MeshTypeCylinder:
			return @"Cylinder";
		case MeshTypeSphere:
			return @"Sphere";
		default:
			return nil;
	}
}

+ (void)setNormalShader:(ShaderProgram *)shaderProgram
{
	normalShader = shaderProgram;
}

+ (void)setFlippedShader:(ShaderProgram *)shaderProgram
{
	flippedShader = shaderProgram;
}

- (uint)vertexCount
{
	return vertices->size();
}

- (uint)triangleCount
{
	return triangles->size();
}

- (uint)edgeCount
{
	return edges->size();
}

- (id)init
{
	self = [super init];
	if (self)
	{
		vertices = new vector<Vector3D>();
		triangles = new vector<Triangle>();
		edges = new vector<Edge>();
		selected = new vector<BOOL>();
		markedVertices = new vector<BOOL>();
		selectionMode = MeshSelectionModeVertices;
		float hue = (random() % 10) / 10.0f;
		color = [NSColor colorWithCalibratedHue:hue 
									 saturation:0.5f
									 brightness:0.6f 
										  alpha:1.0f];
		[color retain];
		
		cachedVertices = NULL;
		cachedNormals = NULL;
		cachedColors = NULL;
	}
	return self;
}

- (void)dealloc
{
	delete vertices;
	delete triangles;
	delete edges;
	delete selected;
	delete markedVertices;
	[color release];
	[self resetCache];
	[super dealloc];
}

- (void)setSelectionMode:(enum MeshSelectionMode)value
{
	selectionMode = value;
	selected->clear();
	switch (selectionMode) 
	{
		case MeshSelectionModeVertices:
		{
			for (uint i = 0; i < vertices->size(); i++)
			{
				selected->push_back(NO);
			}
		} break;
		case MeshSelectionModeTriangles:
		{
			for (uint i = 0; i < triangles->size(); i++)
			{
				selected->push_back(NO);
			}
		} break;
		case MeshSelectionModeEdges:
		{
			[self makeEdges];
			for (uint i = 0; i < edges->size(); i++)
			{
				selected->push_back(NO);
			}
		} break;
	}
}

- (Vector3D)vertexAtIndex:(uint)anIndex
{
	return vertices->at(anIndex);
}

- (Triangle)triangleAtIndex:(uint)anIndex
{
	return triangles->at(anIndex);
}

- (Edge)edgeAtIndex:(uint)anIndex
{
	return edges->at(anIndex);
}

- (BOOL)isVertexMarkedAtIndex:(uint)anIndex
{
	return markedVertices->at(anIndex);
}

- (void)setVertexMarked:(BOOL)isMarked atIndex:(uint)anIndex
{
	markedVertices->at(anIndex) = isMarked;
}

- (void)addVertex:(Vector3D)aVertex
{
	vertices->push_back(aVertex);
	if (selectionMode == MeshSelectionModeVertices)
		selected->push_back(NO);
}

- (void)addTriangle:(Triangle)aTriangle
{
	triangles->push_back(aTriangle);
	if (selectionMode == MeshSelectionModeTriangles)
		selected->push_back(NO);
}

- (void)addTriangleWithIndex1:(uint)index1
					   index2:(uint)index2
					   index3:(uint)index3
{
	Triangle triangle;
	triangle.vertexIndices[0] = index1;
	triangle.vertexIndices[1] = index2;
	triangle.vertexIndices[2] = index3;
	[self addTriangle:triangle];
}

- (void)addQuadWithIndex1:(uint)index1
				   index2:(uint)index2
				   index3:(uint)index3 
				   index4:(uint)index4
{
	Triangle triangle1, triangle2;
	triangle1.vertexIndices[0] = index1;
	triangle1.vertexIndices[1] = index2;
	triangle1.vertexIndices[2] = index3;
	
	triangle2.vertexIndices[0] = index1;
	triangle2.vertexIndices[1] = index3;
	triangle2.vertexIndices[2] = index4;
	
	[self addTriangle:triangle1];
	[self addTriangle:triangle2];
}

- (void)addEdgeWithIndex1:(uint)index1
				   index2:(uint)index2
{
	Edge edge;
	edge.vertexIndices[0] = index1;
	edge.vertexIndices[1] = index2;
	edges->push_back(edge);
	
	if (selectionMode == MeshSelectionModeEdges)
		selected->push_back(NO);
}

- (void)resetCache
{
	if (cachedVertices)
	{
		delete [] cachedVertices;
		cachedVertices = NULL;
	}
	if (cachedNormals)
	{
		delete [] cachedNormals;
		cachedNormals = NULL;
	}
	if (cachedColors)
	{
		delete [] cachedColors;
		cachedColors = NULL;
	}
}

- (void)fillCache
{
	if (!cachedVertices)
	{		
		cachedVertices = new Vector3D[triangles->size() * 3];
		cachedNormals = new Vector3D[triangles->size() * 3];
		cachedColors = new Vector3D[triangles->size() * 3];
		Vector3D triangleVertices[3];
		
		for (uint i = 0; i < triangles->size(); i++)
		{
			Triangle currentTriangle = [self triangleAtIndex:i];
			[self getTriangleVertices:triangleVertices fromTriangle:currentTriangle];
			
			Vector3D n = NormalFromTriangleVertices(triangleVertices);
			
			for (uint j = 0; j < 3; j++)
			{
				cachedVertices[i * 3 + j] = triangleVertices[j];
				cachedNormals[i * 3 + j] = n;
			}
		}
	}
}

- (void)updateColorCache
{
	CGFloat components[4];
	[color getComponents:components];

	for (uint i = 0; i < triangles->size(); i++)
	{
		if ((*selected)[i])
		{
			for (uint j = 0; j < 3; j++)
			{
				cachedColors[i * 3 + j].x = 0.7f;
				cachedColors[i * 3 + j].y = 0.0f;
				cachedColors[i * 3 + j].z = 0.0f;
			}				
		}
		else
		{
			for (uint j = 0; j < 3; j++)
			{
				for (uint k = 0; k < 3; k++)
				{
					cachedColors[i * 3 + j][k] = components[k];
				}
			}	
		}
	}
}

- (void)drawFill
{
	[self fillCache];
	if (selectionMode == MeshSelectionModeTriangles)
		[self updateColorCache];
	else
		glColor3f([color redComponent], [color greenComponent], [color blueComponent]);
		
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	if (selectionMode == MeshSelectionModeTriangles)
	{
		glEnableClientState(GL_COLOR_ARRAY);
		float *colorPtr = (float *)cachedColors;
		glColorPointer(3, GL_FLOAT, 0, colorPtr);
	}
	
	float *vertexPtr = (float *)cachedVertices;
	float *normalPtr = (float *)cachedNormals;
	
	glNormalPointer(GL_FLOAT, 0, normalPtr);
	glVertexPointer(3, GL_FLOAT, 0, vertexPtr);
	glDrawArrays(GL_TRIANGLES, 0, triangles->size() * 3);
	
	if (selectionMode == MeshSelectionModeTriangles)
		glDisableClientState(GL_COLOR_ARRAY);
	
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
}

- (void)drawWire
{
	if (selectionMode != MeshSelectionModeEdges)
	{
		glColor3f([color redComponent] - 0.1f, [color greenComponent] - 0.1f, [color blueComponent] - 0.1f);
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
		[self drawFill];
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	}
}

- (void)useShader:(BOOL)flipped
{
	if (flipped)
		[flippedShader useProgram];
	else
		[normalShader useProgram];
}

- (void)drawWithMode:(enum ViewMode)mode scale:(Vector3D)scale selected:(BOOL)isSelected
{
	BOOL flipped = scale.x < 0.0f || scale.y < 0.0f || scale.z < 0.0f;
	
	glPushMatrix();
	glScalef(scale.x, scale.y, scale.z);
	if (mode == ViewModeWireframe)
	{
		[self drawWire];
	}
	else
	{
		if (isSelected)
		{
			glEnable(GL_POLYGON_OFFSET_FILL);
			glPolygonOffset(1.0f, 1.0f);
			[self useShader:flipped];
			[self drawFill];
			[ShaderProgram resetProgram];
			glDisable(GL_POLYGON_OFFSET_FILL);
			[self drawWire];
		}
		else
		{
			[self useShader:flipped];
			[self drawFill];
			[ShaderProgram resetProgram];
		}
	}
	glPopMatrix();
}

- (void)makeMeshWithType:(enum MeshType)type steps:(uint)steps
{
	switch (type) 
	{
		case MeshTypeCube:
			[self makeCube];
			break;
		case MeshTypeCylinder:
			[self makeCylinderWithSteps:steps];
			break;
		case MeshTypeSphere:
			[self makeSphereWithSteps:steps];
			break;
		default:
			NSLog(@"Unknown mesh type: %i", type);
			break;
	}
}

- (void)makeCube
{
	NSLog(@"makeCube");
	
	vertices->clear();
	triangles->clear();
	selected->clear();
	
	// back vertices
	vertices->push_back(Vector3D(-1, -1, -1)); // 0
	vertices->push_back(Vector3D( 1, -1, -1)); // 1
	vertices->push_back(Vector3D( 1,  1, -1)); // 2
	vertices->push_back(Vector3D(-1,  1, -1)); // 3
	
	// front vertices
	vertices->push_back(Vector3D(-1, -1,  1)); // 4
	vertices->push_back(Vector3D( 1, -1,  1)); // 5
	vertices->push_back(Vector3D( 1,  1,  1)); // 6
	vertices->push_back(Vector3D(-1,  1,  1)); // 7
	
	// back triangles
	[self addQuadWithIndex1:0 index2:1 index3:2 index4:3];
	
	// front triangles
	[self addQuadWithIndex1:7 index2:6 index3:5 index4:4];
	
	// bottom triangles
	[self addQuadWithIndex1:1 index2:0 index3:4 index4:5];
	
	// top triangles
	[self addQuadWithIndex1:3 index2:2 index3:6 index4:7];
	
	// left triangles
	[self addQuadWithIndex1:7 index2:4 index3:0 index4:3];
	
	// right triangles
	[self addQuadWithIndex1:2 index2:1 index3:5 index4:6];
	
	[self setSelectionMode:[self selectionMode]];
}

- (void)makeCylinderWithSteps:(uint)steps
{
	NSLog(@"makeCylinderWithSteps:%i", steps);
	
	vertices->clear();
	triangles->clear();
	selected->clear();
	
	vertices->push_back(Vector3D(0, -1, 0)); // 0
 	vertices->push_back(Vector3D(0,  1, 0)); // 1
	
	vertices->push_back(Vector3D(cosf(0.0f), -1, sinf(0.0f))); // 2
	vertices->push_back(Vector3D(cosf(0.0f),  1, sinf(0.0f))); // 3
		
	uint max = steps;
	float step = (FLOAT_PI * 2.0f) / max;
	float angle = step;
	for (uint i = 1; i < max; i++)
	{
		vertices->push_back(Vector3D(cosf(angle), -1, sinf(angle))); // 4
		vertices->push_back(Vector3D(cosf(angle),  1, sinf(angle))); // 5
		
		Triangle triangle1, triangle2;
		triangle1.vertexIndices[0] = vertices->size() - 3;
		triangle1.vertexIndices[1] = vertices->size() - 2;
		triangle1.vertexIndices[2] = vertices->size() - 1;
	
		triangle2.vertexIndices[0] = vertices->size() - 2;
		triangle2.vertexIndices[1] = vertices->size() - 3;
		triangle2.vertexIndices[2] = vertices->size() - 4;
		
		triangles->push_back(triangle1);
		triangles->push_back(triangle2);
		
		Triangle triangle3, triangle4;
		triangle3.vertexIndices[0] = vertices->size() - 4;
		triangle3.vertexIndices[1] = 0;
		triangle3.vertexIndices[2] = vertices->size() - 2;
		
		triangle4.vertexIndices[0] = vertices->size() - 3;
		triangle4.vertexIndices[1] = vertices->size() - 1;
		triangle4.vertexIndices[2] = 1;
		
		triangles->push_back(triangle3);
		triangles->push_back(triangle4);
		
		angle += step;
	}
	
	Triangle triangle1, triangle2;
	triangle1.vertexIndices[0] = 2;
	triangle1.vertexIndices[1] = 3;
	triangle1.vertexIndices[2] = vertices->size() - 1;
	
	triangle2.vertexIndices[0] = vertices->size() - 1;
	triangle2.vertexIndices[1] = vertices->size() - 2;
	triangle2.vertexIndices[2] = 2;
	
	triangles->push_back(triangle1);
	triangles->push_back(triangle2);
	
	Triangle triangle3, triangle4;
	triangle3.vertexIndices[0] = 0;
	triangle3.vertexIndices[1] = 2;
	triangle3.vertexIndices[2] = vertices->size() - 2;
	
	triangle4.vertexIndices[0] = 3;
	triangle4.vertexIndices[1] = 1;
	triangle4.vertexIndices[2] = vertices->size() - 1;
	
	triangles->push_back(triangle3);
	triangles->push_back(triangle4);
	
	[self setSelectionMode:[self selectionMode]];
}

- (void)makeSphereWithSteps:(uint)steps
{
	NSLog(@"makeSphereWithSteps:%i", steps);
	
	vertices->clear();
	triangles->clear();
	selected->clear();
		
	uint max = steps;
	
	vertices->push_back(Vector3D(0, 1, 0));
	vertices->push_back(Vector3D(0, -1, 0));
	
	float step = FLOAT_PI / max;
	
	for (uint i = 0; i < max; i++)
	{
		float beta = i * step * 2.0f;
		
		for (uint j = 1; j < max; j++)
		{
			float alpha = 0.5f * FLOAT_PI + j * step;
			float y0 = sinf(alpha);
			float w0 = cosf(alpha);                
	
			float x0 = sinf(beta) * w0;
			float z0 = cosf(beta) * w0;
						
			vertices->push_back(Vector3D(x0, y0, z0));
						
			if (i > 0 && j < max - 1)
			{
				int index = (i - 1) * (max - 1);
				[self addQuadWithIndex1:1 + max + j + index
								 index2:2 + j + index
								 index3:1 + j + index
								 index4:max + j + index];
			}
		}
		
		int index = i * (max - 1);
		if (i < max - 1)
		{
			[self addTriangleWithIndex1:0
								 index2:2 + index + max - 1
								 index3:2 + index];
			
			[self addTriangleWithIndex1:1
								 index2:index + max
								 index3:index + 2 * max - 1];
		}
		else 
		{
			[self addTriangleWithIndex1:0
								 index2:2
								 index3:2 + index];
			
			[self addTriangleWithIndex1:1
								 index2:index + max
								 index3:max];
		}
	}
	
	for (uint j = 1; j < max - 1; j++)
	{
		int index = (max - 1) * (max - 1);
		[self addQuadWithIndex1:1 + j + index
						 index2:1 + j
						 index3:2 + j
						 index4:2 + j + index];
	}
		
	[self setSelectionMode:[self selectionMode]];
}

- (void)makeEdges
{
	[self resetCache];
	
	edges->clear();
	for (uint i = 0; i < triangles->size(); i++)
	{
		Triangle triangle = triangles->at(i);
		Edge triangleEdges[3];
		BOOL addTriangleEdges[3];
		
		for (uint j = 0; j < 3; j++)
		{
			addTriangleEdges[j] = YES;
			if (j == 2)
			{
				triangleEdges[j].vertexIndices[0] = triangle.vertexIndices[2];
				triangleEdges[j].vertexIndices[1] = triangle.vertexIndices[0];
			}
			else
			{
				triangleEdges[j].vertexIndices[0] = triangle.vertexIndices[j];
				triangleEdges[j].vertexIndices[1] = triangle.vertexIndices[j + 1];
			}
		}

		int falseCounter = 0;
		
		for (uint j = 0; j < edges->size(); j++)
		{
			Edge edge = edges->at(j);
			for (uint k = 0; k < 3; k++)
			{
				if (addTriangleEdges[k] && 
					AreEdgesSame(triangleEdges[k], edge))
				{
					addTriangleEdges[k] = NO;
					falseCounter++;
					break;
				}
			}
			if (falseCounter == 3)
				break;
		}
		
		for (uint j = 0; j < 3; j++)
		{
			if (addTriangleEdges[j])
				edges->push_back(triangleEdges[j]);
		}
	}
	
	NSLog(@"edgeCount:%i", [self edgeCount]);
}

- (void)makeMarkedVertices
{
	NSLog(@"makeMarkedVertices");
	[self resetCache];
	
	markedVertices->resize(vertices->size());
	for (uint i = 0; i < markedVertices->size(); i++)
	{
		markedVertices->at(i) = NO;
	}
	
	switch (selectionMode)
	{
		case MeshSelectionModeVertices:
		{
			for (uint i = 0; i < vertices->size(); i++)
			{
				if (selected->at(i))
					markedVertices->at(i) = YES;
			}
		} break;
		case MeshSelectionModeTriangles:
		{
			for (uint i = 0; i < triangles->size(); i++)
			{
				if (selected->at(i))
				{
					[self setTriangleMarked:YES atIndex:i];
				}
			}
		} break;
		case MeshSelectionModeEdges:
		{
			for (uint i = 0; i < edges->size(); i++)
			{
				if (selected->at(i))
				{
					[self setEdgeMarked:YES atIndex:i];
				}
			}
		} break;
		default:
			break;
	}
}

- (void)removeVertexAtIndex:(uint)index
{
	for (uint i = 0; i < triangles->size(); i++)
	{
		for (uint j = 0; j < 3; j++)
		{
			if (triangles->at(i).vertexIndices[j] >= index)
				triangles->at(i).vertexIndices[j]--;
		}
	}
	vertices->erase(vertices->begin() + index);
	if (selectionMode == MeshSelectionModeVertices)
		selected->erase(selected->begin() + index);
}

- (void)removeTriangleAtIndex:(uint)index
{
	triangles->erase(triangles->begin() + index);
	if (selectionMode == MeshSelectionModeTriangles)
		selected->erase(selected->begin() + index);
}

- (void)removeEdgeAtIndex:(uint)index
{
	edges->erase(edges->begin() + index);
	if (selectionMode == MeshSelectionModeEdges)
		selected->erase(selected->begin() + index);
}

- (void)removeDegeneratedTriangles
{
	NSLog(@"removeDegeneratedTriangles");
	[self resetCache];
	
	for (int i = 0; i < (int)triangles->size(); i++)
	{
		if (IsTriangleDegenerated(triangles->at(i)))
		{
			[self removeTriangleAtIndex:i];
			i--;
		}
	}	
}

- (BOOL)isVertexUsedAtIndex:(uint)index
{
	for (uint i = 0; i < triangles->size(); i++)
	{
		Triangle triangle = triangles->at(i);
		for (uint j = 0; j < 3; j++)
		{
			if (triangle.vertexIndices[j] == index)
				return YES;
		}
	}
	return NO;
}

- (void)removeNonUsedVertices
{
	NSLog(@"removeNonUsedVertices");
	[self resetCache];
	
	for (int i = 0; i < (int)vertices->size(); i++)
	{
		if (![self isVertexUsedAtIndex:i])
		{
			[self removeVertexAtIndex:i];
			i--;
		}
	}
}

- (void)removeSelectedVertices
{
	NSLog(@"removeSelectedVertices");
	[self resetCache];
	
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
	
	for (int i = 0; i < (int)selected->size(); i++)
	{
		if (selected->at(i))
		{
			[self removeVertexAtIndex:i];
			i--;
		}
	}
}

- (void)fastMergeVertexFirst:(uint)firstIndex second:(uint)secondIndex
{
	NSLog(@"fastMergeVertexFirst:%i second:%i", firstIndex, secondIndex);
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
	
	Vector3D first = [self vertexAtIndex:firstIndex];
	Vector3D second = [self vertexAtIndex:secondIndex];
	Vector3D center = first + second;
	center /= 2;
	
	vertices->push_back(center);
	selected->push_back(NO);
	
	uint centerIndex = vertices->size() - 1;
	
	for (uint i = 0; i < triangles->size(); i++)
	{
		for (uint j = 0; j < 3; j++)
		{
			if (triangles->at(i).vertexIndices[j] == firstIndex ||
				triangles->at(i).vertexIndices[j] == secondIndex)
			{
				triangles->at(i).vertexIndices[j] = centerIndex;
			}
		}
	}
	
	// erasing should happen from the back of STL vector 
	if (firstIndex > secondIndex)
	{
		[self removeVertexAtIndex:firstIndex];
		[self removeVertexAtIndex:secondIndex];
	}
	else
	{
		[self removeVertexAtIndex:secondIndex];
		[self removeVertexAtIndex:firstIndex];
	}
	
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
}

- (void)fastMergeSelectedVertices
{
	NSLog(@"fastMergeSelectedVertices");
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
	
	uint selectedCount = 0;
	Vector3D center = Vector3D();
	
	for (uint i = 0; i < selected->size(); i++)
	{
		if (selected->at(i))
		{
			selectedCount++;
			center += vertices->at(i);
		}
	}
	
	NSLog(@"selectedCount = %i", selectedCount);
	
	if (selectedCount < 2)
		return;
	
	center /= selectedCount;
	vertices->push_back(center);
	selected->push_back(NO);
	
	uint centerIndex = vertices->size() - 1;
	
	for (uint i = 0; i < selected->size(); i++)
	{
		if (selected->at(i))
		{
			for (uint j = 0; j < triangles->size(); j++)
			{
				for (uint k = 0; k < 3; k++)
				{
					if (triangles->at(j).vertexIndices[k] == i)
						triangles->at(j).vertexIndices[k] = centerIndex;
				}				
			}
		}
	}
	
	[self removeSelectedVertices];
}

- (void)mergeSelectedVertices
{
	NSLog(@"mergeSelectedVertices");
	[self resetCache];
	
	[self fastMergeSelectedVertices];
	
	[self removeDegeneratedTriangles];
	[self removeNonUsedVertices];
	
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
}

- (void)mergeVertexPairs
{
	NSLog(@"mergeVertexPairs");
	[self resetCache];
	
	for (int i = 0; i < (int)selected->size(); i++)
	{
		if (selected->at(i))
		{
			Vector3D firstVertex = [self vertexAtIndex:i];
			float smallestDistance = 10.0f; // maximum distance between vertices in pair
			int secondIndex = -1;
			for (int j = i + 1; j < (int)selected->size(); j++)
			{
				if (selected->at(j))
				{
					Vector3D secondVertex = [self vertexAtIndex:j];
					float currentDistance = firstVertex.Distance(secondVertex);
					if (currentDistance < smallestDistance)
					{
						secondIndex = j;
						smallestDistance = currentDistance;
					}
				}
			}
			
			if (secondIndex > -1)
			{
				[self fastMergeVertexFirst:i second:secondIndex];
				i--;
			}
		}
	}
		
	[self removeDegeneratedTriangles];
	[self removeNonUsedVertices];
	
	NSAssert(vertices->size() == selected->size(), @"vertices->size() == selected->size()");
}

- (void)transformWithMatrix:(Matrix4x4)matrix
{
	[self resetCache];
	for (uint i = 0; i < vertices->size(); i++)
		vertices->at(i).Transform(matrix);
}

- (void)mergeWithMesh:(Mesh *)mesh
{
	NSLog(@"mergeWithMesh:");
	[self resetCache];
	
	uint vertexCount = vertices->size();
	for (uint i = 0; i < mesh->vertices->size(); i++)
	{
		vertices->push_back(mesh->vertices->at(i));
	}
	for (uint i = 0; i < mesh->triangles->size(); i++)
	{
		Triangle triangle = mesh->triangles->at(i);
		triangle.vertexIndices[0] += vertexCount;
		triangle.vertexIndices[1] += vertexCount;
		triangle.vertexIndices[2] += vertexCount;
		triangles->push_back(triangle);
	}
	selected->clear();
	for (uint i = 0; i < vertices->size(); i++)
		selected->push_back(NO);
}

- (void)getTriangleVertices:(Vector3D *)triangleVertices fromTriangle:(Triangle)triangle
{
	for (uint i = 0; i < 3; i++)
	{
		triangleVertices[i] = [self vertexAtIndex:triangle.vertexIndices[i]];
	}
}

- (void)splitTriangleAtIndex:(uint)index
{
	NSLog(@"splitTriangleAtIndex:%i", index);
	
	Triangle triangle = [self triangleAtIndex:index];
	Vector3D triangleVertices[3];
	[self getTriangleVertices:triangleVertices fromTriangle:triangle];
	
	Vector3D centerVertex = Vector3D();
	
	for (uint i = 0; i < 3; i++)
		centerVertex +=	triangleVertices[i];
	
	centerVertex /= 3;
	
	vertices->push_back(centerVertex);
	
	uint centerVertexIndex = vertices->size() - 1;
	
	Vector3D triangleNormal = NormalFromTriangleVertices(triangleVertices);
		
	for (uint i = 0; i < 3; i++)
	{
		Triangle newTriangle;
		
		if (i == 2)
		{
			newTriangle = MakeTriangle(triangle.vertexIndices[2], 
									   triangle.vertexIndices[0], 
									   centerVertexIndex);
		}
		else
		{
			newTriangle = MakeTriangle(triangle.vertexIndices[i], 
									   triangle.vertexIndices[i + 1], 
									   centerVertexIndex);
		}
		
		[self getTriangleVertices:triangleVertices fromTriangle:newTriangle];
		
		Vector3D newTriangleNormal = NormalFromTriangleVertices(triangleVertices);
		
		if (triangleNormal.Dot(newTriangleNormal) < 0)
			newTriangle = FlipTriangle(newTriangle);
		
		[self addTriangle:newTriangle];
	}
	
	[self removeTriangleAtIndex:index];
}

- (void)splitEdgeAtIndex:(uint)index
{
	NSLog(@"splitEdgeAtIndex:%i", index);
	
	Edge edge = [self edgeAtIndex:index];
	[self removeEdgeAtIndex:index];
	Vector3D firstVertex = [self vertexAtIndex:edge.vertexIndices[0]];
	Vector3D secondVertex = [self vertexAtIndex:edge.vertexIndices[1]];
	Vector3D centerVertex = firstVertex + secondVertex;
	centerVertex /= 2.0f;
	vertices->push_back(centerVertex);
	uint centerIndex = vertices->size() - 1;
	
	Vector3D triangleVertices[3];
		
	for (int i = 0; i < (int)triangles->size(); i++)
	{
		Triangle triangle = [self triangleAtIndex:i];
		if (IsEdgeInTriangle(triangle, edge))
		{
			uint oppositeIndex = NonEdgeIndexInTriangle(triangle, edge);
			
			[self removeTriangleAtIndex:i];
			i--;
			
			[self addEdgeWithIndex1:centerIndex index2:oppositeIndex];
			
			[self getTriangleVertices:triangleVertices fromTriangle:triangle];
			Vector3D splittedTriangleNormal = NormalFromTriangleVertices(triangleVertices);
			
			Triangle firstTriangle = MakeTriangle(edge.vertexIndices[0], oppositeIndex, centerIndex);
			[self getTriangleVertices:triangleVertices fromTriangle:firstTriangle];
			Vector3D firstTriangleNormal = NormalFromTriangleVertices(triangleVertices);
			
			Triangle secondTriangle = MakeTriangle(edge.vertexIndices[1], oppositeIndex, centerIndex);
			[self getTriangleVertices:triangleVertices fromTriangle:secondTriangle];
			Vector3D secondTriangleNormal = NormalFromTriangleVertices(triangleVertices);
			
			if (firstTriangleNormal.Dot(splittedTriangleNormal) < 0.0f)
				firstTriangle = FlipTriangle(firstTriangle);
			
			if (secondTriangleNormal.Dot(splittedTriangleNormal) < 0.0f)
				secondTriangle = FlipTriangle(secondTriangle);
			
			[self addTriangle:firstTriangle];
			[self addTriangle:secondTriangle];
		}
	}
	
	[self addEdgeWithIndex1:centerIndex index2:edge.vertexIndices[1]];
	[self addEdgeWithIndex1:centerIndex index2:edge.vertexIndices[0]];
}

- (void)splitSelectedEdges
{
	NSLog(@"splitSelectedEdges");
	[self resetCache];
	
	for (int i = 0; i < (int)selected->size(); i++)
	{
		if (selected->at(i))
		{
			[self splitEdgeAtIndex:i];
			i--;
		}
	}
}

- (void)splitSelectedTriangles
{
	NSLog(@"splitSelectedTriangles");
	[self resetCache];
	
	for (int i = 0; i < (int)selected->size(); i++)
	{
		if (selected->at(i))
		{
			[self splitTriangleAtIndex:i];
			i--;
		}
	}
}

- (void)turnEdgeAtIndex:(uint)index
{
	NSLog(@"turnEdgeAtIndex:%i", index);
	
	Edge edge = [self edgeAtIndex:index];
	uint counter = 0;
	uint oldTriangleIndices[2];
	Triangle oldTriangles[2];
	
	for (uint i = 0; i < triangles->size(); i++)
	{
		Triangle triangle = [self triangleAtIndex:i];
		if (IsEdgeInTriangle(triangle, edge))
		{
			oldTriangleIndices[counter] = i;
			oldTriangles[counter] = triangle;
			counter++;
			if (counter == 2)
			{
				Edge turned;
				turned.vertexIndices[0] = NonEdgeIndexInTriangle(oldTriangles[0], edge);
				turned.vertexIndices[1] = NonEdgeIndexInTriangle(oldTriangles[1], edge);
				
				Vector3D triangleVertices[3];
				
				[self getTriangleVertices:triangleVertices fromTriangle:oldTriangles[0]];
				Vector3D oldTriangleNormal1 = NormalFromTriangleVertices(triangleVertices);
				
				[self getTriangleVertices:triangleVertices fromTriangle:oldTriangles[1]];
				Vector3D oldTriangleNormal2 = NormalFromTriangleVertices(triangleVertices);
				
				for (int j = 0; j < 2; j++)
				{
					Triangle newTriangle = MakeTriangle(edge.vertexIndices[j], 
														turned.vertexIndices[0], 
														turned.vertexIndices[1]);
										
					[self getTriangleVertices:triangleVertices fromTriangle:newTriangle];
					Vector3D newTriangleNormal = NormalFromTriangleVertices(triangleVertices);
					
					// two dot products, it is working, but not in all cases
					if (newTriangleNormal.Dot(oldTriangleNormal1) < 0.0f ||
						newTriangleNormal.Dot(oldTriangleNormal2) < 0.0f)
					{
						newTriangle = FlipTriangle(newTriangle);
						NSLog(@"opposite in turnEdgeAtIndex	");
					}
					
					triangles->at(oldTriangleIndices[j]) = newTriangle;
				}
								
				edges->at(index) = turned;
				
				return;
			}
		}
	}
}

- (void)turnSelectedEdges
{
	NSLog(@"turnSelectedEdges");
	
	for (uint i = 0; i < selected->size(); i++)
	{
		if (selected->at(i))
		{
			[self turnEdgeAtIndex:i];
			
			// uncomment this line to deselect after edge turn
			//selected->at(i) = NO;
		}
	}
}

- (void)mergeSelected
{
	NSLog(@"mergeSelected");
	
	switch (selectionMode)
	{
		case MeshSelectionModeVertices:
			[self mergeSelectedVertices];
			break;
		default:
			break;
	}
}

- (void)splitSelected
{
	NSLog(@"splitSelected");
	
	switch (selectionMode)
	{
		case MeshSelectionModeEdges:
			[self splitSelectedEdges];
			break;
		case MeshSelectionModeTriangles:
			[self splitSelectedTriangles];
			break;
		default:
			break;
	}
}

#pragma mark OpenGLManipulatingModel implementation

- (uint)count
{
	return selected->size();	
}

- (void)didSelect
{
	[self makeMarkedVertices];
}

- (void)getSelectionCenter:(Vector3D *)center 
				  rotation:(Quaternion *)rotation
					 scale:(Vector3D *)scale
{
	if (markedVertices->size() != vertices->size())
	{
		[self makeMarkedVertices];
	}
	
	*center = Vector3D();
	*rotation = Quaternion();
	*scale = Vector3D(1, 1, 1);

	uint markedCount = 0;
	for (uint i = 0; i < markedVertices->size(); i++)
	{
		if (markedVertices->at(i))
		{
			*center += vertices->at(i);
			markedCount++;
		}
	}
	if (markedCount > 0)
		*center /= (float)markedCount;
	
	NSLog(@"markedCount = %i", markedCount);
}

- (void)moveSelectedByOffset:(Vector3D)offset
{
	[self resetCache];
	
	if (markedVertices->size() != vertices->size())
	{
		[self makeMarkedVertices];
	}
	
	for (uint i = 0; i < markedVertices->size(); i++)
	{
		if (markedVertices->at(i))
			vertices->at(i) += offset;
	}
}

- (void)rotateSelectedByOffset:(Quaternion)offset
{
	[self resetCache];
	
	if (markedVertices->size() != vertices->size())
	{
		[self makeMarkedVertices];
	}
	
	for (uint i = 0; i < markedVertices->size(); i++)
	{
		if (markedVertices->at(i))
			vertices->at(i).Transform(offset);
	}
}

- (void)scaleSelectedByOffset:(Vector3D)offset
{
	[self resetCache];
	
	if (markedVertices->size() != vertices->size())
	{
		[self makeMarkedVertices];
	}
	
	for (uint i = 0; i < markedVertices->size(); i++)
	{
		if (markedVertices->at(i))
		{
			Vector3D &v = vertices->at(i);
			v.x *= offset.x;
			v.y *= offset.y;
			v.z *= offset.z;
		}
	}	
}

- (BOOL)isSelectedAtIndex:(uint)index
{
	return selected->at(index);
}

- (void)setEdgeMarked:(BOOL)isMarked atIndex:(uint)index
{
	Edge edge = [self edgeAtIndex:index];
	markedVertices->at(edge.vertexIndices[0]) = isMarked;
	markedVertices->at(edge.vertexIndices[1]) = isMarked;
}

- (void)setTriangleMarked:(BOOL)isMarked atIndex:(uint)index
{
	Triangle triangle = [self triangleAtIndex:index];
	markedVertices->at(triangle.vertexIndices[0]) = isMarked;
	markedVertices->at(triangle.vertexIndices[1]) = isMarked;
	markedVertices->at(triangle.vertexIndices[2]) = isMarked;
}

- (void)setSelected:(BOOL)isSelected atIndex:(uint)index 
{
	selected->at(index) = isSelected;
}

- (void)drawAtIndex:(uint)index forSelection:(BOOL)forSelection withMode:(enum ViewMode)mode
{
	switch (selectionMode) 
	{
		case MeshSelectionModeVertices:
		{
			Vector3D v = [self vertexAtIndex:index];
			if (!forSelection)
			{
				BOOL isSelected = selected->at(index);
				glPointSize(5.0f);
				if (isSelected)
					glColor3f(1, 0, 0);
				else
					glColor3f(0, 0, 1);
				glDisable(GL_LIGHTING);
			}
			glBegin(GL_POINTS);
			glVertex3f(v.x, v.y, v.z);
			glEnd();
		} break;
		case MeshSelectionModeTriangles:
		{
			if (forSelection)
			{
				Triangle currentTriangle = [self triangleAtIndex:index];
				glBegin(GL_TRIANGLES);
				for (uint i = 0; i < 3; i++)
				{
					Vector3D v = [self vertexAtIndex:currentTriangle.vertexIndices[i]];
					glVertex3f(v.x, v.y, v.z);
				}
				glEnd();
			}
		} break;
		case MeshSelectionModeEdges:
		{
			Edge currentEdge = [self edgeAtIndex:index];
			if (!forSelection)
			{
				BOOL isSelected = selected->at(index);
				if (isSelected)
					glColor3f(1, 0, 0);
				else
					glColor3f(1, 1, 1);
				glDisable(GL_LIGHTING);
			}
			glBegin(GL_LINES);
			for (uint i = 0; i < 2; i++)
			{
				Vector3D v = [self vertexAtIndex:currentEdge.vertexIndices[i]];
				glVertex3f(v.x, v.y, v.z);
			}
			glEnd();
		} break;
	}
}

- (void)extrudeSelectedTriangles
{
	[self resetCache];
	
	// This method finds all nonShared edges and copies all 
	// vertexIndices in selectedTriangles.
	// Then it makes quads between new and old edges.
	
	vector<uint> *vertexIndices = new vector<uint>();
	vector<Edge> *nonSharedEdges = new vector<Edge>();
	
	uint triCount = [self triangleCount];
	uint vertCount = [self vertexCount];
	
	for (uint i = 0; i < triCount; i++)
	{
		if (selected->at(i))
		{
			[self setTriangleMarked:NO atIndex:i];
			Triangle &triangle = triangles->at(i);
			
			for (uint j = 0; j < 3; j++)
			{
				int foundIndex = -1;
				for (uint k = 0; k < vertexIndices->size(); k++)
				{
					if (vertexIndices->at(k) == triangle.vertexIndices[j])
					{
						foundIndex = k;
						break;
					}
				}
								
				uint &index = triangle.vertexIndices[j];
							
				if (foundIndex < 0)
				{
					vertexIndices->push_back(index);
					vertices->push_back(vertices->at(index));
					markedVertices->push_back(YES);
					index = vertCount + vertexIndices->size() - 1;
				}
				else
				{
					index = vertCount + foundIndex;
				}
			}
			
			for (uint j = 0; j < 3; j++)
			{
				Edge edge;
				edge.vertexIndices[0] = triangle.vertexIndices[j];
				edge.vertexIndices[1] = triangle.vertexIndices[j + 1 < 3 ? j + 1 : 0];

				BOOL foundEdge = NO;
				for (uint k = 0; k < nonSharedEdges->size(); k++)
				{
					if (AreEdgesSame(edge, nonSharedEdges->at(k)))
					{
						nonSharedEdges->erase(nonSharedEdges->begin() + k);
						foundEdge = YES;
						break;
					}
				}
				
				if (!foundEdge)
				{
					nonSharedEdges->push_back(edge);
				}
			}
		}
	}
	
	for (uint i = 0; i < nonSharedEdges->size(); i++)
	{
		Edge edge = nonSharedEdges->at(i);
		[self addQuadWithIndex1:edge.vertexIndices[0]
						 index2:vertexIndices->at(edge.vertexIndices[0] - vertCount)
						 index3:vertexIndices->at(edge.vertexIndices[1] - vertCount)
						 index4:edge.vertexIndices[1]];
	}
		
	delete vertexIndices;
	delete nonSharedEdges;
	
	[self removeNonUsedVertices]; // slow but sometimes neccessary
}

- (void)flipSelected
{
	if (selectionMode == MeshSelectionModeTriangles)
	{
		[self flipSelectedTriangles];
	}
	else if (selectionMode == MeshSelectionModeEdges)
	{
		[self turnSelectedEdges];
	}
}

- (void)cloneSelected
{
	if (selectionMode == MeshSelectionModeTriangles)
	{
		[self extrudeSelectedTriangles];
	}	
}

- (void)removeSelected
{
	if (selectionMode == MeshSelectionModeTriangles)
	{
		for (int i = 0; i < (int)[self triangleCount]; i++)
		{
			if (selected->at(i))
			{
				[self removeTriangleAtIndex:i];
				i--;
			}
		}
		[self removeNonUsedVertices]; // still slow, but called once per selection
	}
}

- (void)flipSelectedTriangles
{
	if (selectionMode == MeshSelectionModeTriangles)
	{	
		[self resetCache];
		for (uint i = 0; i < [self triangleCount]; i++)
		{
			if (selected->at(i))
				[self flipTriangleAtIndex:i];
		}
	}
}

- (void)flipAllTriangles
{
	[self resetCache];
	for (uint i = 0; i < [self triangleCount]; i++)
	{
		[self flipTriangleAtIndex:i];
	}
}
				 
- (void)flipTriangleAtIndex:(uint)index
{
	Triangle &triangle = triangles->at(index);
	triangle = FlipTriangle(triangle);
}

#pragma mark NSCoding implementation

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [self init];
	if (self)
	{		
		NSUInteger tempLength = 0;
		
		const Vector3D *tempVertices = (const Vector3D *)[aDecoder decodeBytesForKey:@"vertices"
																	  returnedLength:&tempLength];
		tempLength /= sizeof(Vector3D);
		
		for (uint i = 0; i < tempLength; i++)
			vertices->push_back(tempVertices[i]);
		
		const Triangle *tempTriangles = (const Triangle *)[aDecoder decodeBytesForKey:@"triangles"
																	   returnedLength:&tempLength];
		tempLength /= sizeof(Triangle);
		
		for (uint i = 0; i < tempLength; i++)
			triangles->push_back(tempTriangles[i]);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	// problem with zero size, should be handled in code for Item
	[aCoder encodeBytes:(uint8_t *)&vertices->at(0) length:vertices->size() * sizeof(Vector3D) forKey:@"vertices"];
	[aCoder encodeBytes:(uint8_t *)&triangles->at(0) length:triangles->size() * sizeof(Triangle) forKey:@"triangles"];
}

#pragma mark CppFileStreaming implementation

- (id)initWithFileStream:(ifstream *)fin
{
	self = [self init];
	if (self)
	{
		uint verticesSize;
		uint trianglesSize;
		fin->read((char *)&verticesSize, sizeof(uint));
		fin->read((char *)&trianglesSize, sizeof(uint));
		
		for (uint i = 0; i < verticesSize; i++)
		{
			Vector3D vertex;
			fin->read((char *)&vertex, sizeof(Vector3D));
			vertices->push_back(vertex);
		}
		
		for (uint i = 0; i < trianglesSize; i++)
		{
			Triangle triangle;
			fin->read((char *)&triangle, sizeof(Triangle));
			triangles->push_back(triangle);
		}
	}
	return self;
}

- (void)encodeWithFileStream:(ofstream *)fout
{
	uint size = vertices->size(); 
	fout->write((char *)&size, sizeof(uint));
	size = triangles->size();
	fout->write((char *)&size, sizeof(uint));
	
	if (vertices->size() > 0)
		fout->write((char *)&vertices->at(0), vertices->size() * sizeof(Vector3D));
	
	if (triangles->size() > 0)
		fout->write((char *)&triangles->at(0), triangles->size() * sizeof(Triangle));
}

@end
