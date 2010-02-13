//
//  ItemCollection.mm
//  OpenGLEditor
//
//  Created by Filip Kunc on 6/28/09.
//  For license see LICENSE.TXT
//

#import <OpenGL/gl.h>
#import "ItemCollection.h"
#import "ItemManipulationState.h"

@implementation ItemCollection

- (id)init
{
	self = [super init];
	if (self)
	{
		items = [[NSMutableArray alloc] init];
	}
	return self;
}

#pragma mark NSCoding implementation

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if (self)
	{
		items = [[aDecoder decodeObjectForKey:@"items"] retain];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:items forKey:@"items"];
}

#pragma mark CppFileStreaming implementation

- (id)initWithFileStream:(ifstream *)fin
{
	self = [super init];
	if (self)
	{
		items = [[NSMutableArray alloc] init];
		uint itemsCount;
		fin->read((char *)&itemsCount, sizeof(uint));
		for (uint i = 0; i < itemsCount; i++)
		{
			Item *item = [[Item alloc] initWithFileStream:fin];
			[items addObject:item];
		}
	}
	return self;
}

- (void)encodeWithFileStream:(ofstream *)fout
{
	uint itemsCount = [items count];
	fout->write((char *)&itemsCount, sizeof(uint));
	for (uint i = 0; i < itemsCount; i++)
	{		
		Item *item = [self itemAtIndex:i];
		[item encodeWithFileStream:fout];
	}
}

- (void)dealloc
{
	[items release];
	[super dealloc];
}

- (Item *)itemAtIndex:(uint)index
{
	return (Item *)[items objectAtIndex:index];
}

- (void)addItem:(Item *)item
{
	[items addObject:item];
}

- (void)removeItem:(Item *)item
{
	[items removeObject:item];
}

- (void)removeLastItem
{
	[items removeLastObject];
}

- (void)removeItemAtIndex:(uint)index
{
	[items removeObjectAtIndex:index];
}

- (void)removeItemsInRange:(NSRange)range
{
	[items removeObjectsInRange:range];
}

- (void)insertItem:(Item *)item atIndex:(uint)index
{
	[items insertObject:item atIndex:index];
}

- (uint)count
{
	return [items count];
}

- (Vector3D)positionAtIndex:(uint)index
{
	return [[self itemAtIndex:index] position];
}

- (Quaternion)rotationAtIndex:(uint)index
{
	return [[self itemAtIndex:index] rotation];
}

- (Vector3D)scaleAtIndex:(uint)index
{
	return [[self itemAtIndex:index] scale];
}

- (void)setPosition:(Vector3D)position atIndex:(uint)index
{
	[[self itemAtIndex:index] setPosition:position];
}

- (void)setRotation:(Quaternion)rotation atIndex:(uint)index
{
	[[self itemAtIndex:index] setRotation:rotation];
}

- (void)setScale:(Vector3D)scale atIndex:(uint)index
{
	[[self itemAtIndex:index] setScale:scale];
}

- (void)moveByOffset:(Vector3D)offset atIndex:(uint)index
{
	[[self itemAtIndex:index] moveByOffset:offset];
}

- (void)rotateByOffset:(Quaternion)offset atIndex:(uint)index
{
	[[self itemAtIndex:index] rotateByOffset:offset];
}

- (void)scaleByOffset:(Vector3D)offset atIndex:(uint)index
{
	[[self itemAtIndex:index] scaleByOffset:offset];
}

- (BOOL)isSelectedAtIndex:(uint)index
{
	return [[self itemAtIndex:index] selected];
}

- (void)setSelected:(BOOL)selected atIndex:(uint)index
{
	[[self itemAtIndex:index] setSelected:selected];
}

- (void)drawAtIndex:(uint)index forSelection:(BOOL)forSelection withMode:(enum ViewMode)mode
{
	[[self itemAtIndex:index] drawWithMode:mode];
}

- (void)cloneSelected
{
	int count = [self count];
	for (int i = 0; i < count; i++)
	{
		if ([self isSelectedAtIndex:i])
		{
			Item *oldItem = [self itemAtIndex:i];
			Item *newItem = [oldItem clone];
			[oldItem setSelected:NO];
			[items addObject:newItem];
			[newItem release];
		}
	}
}

- (void)removeSelected
{
	for (int i = 0; i < (int)[self count]; i++)
	{
		if ([self isSelectedAtIndex:i])
		{
			[items removeObjectAtIndex:i];
			i--;
		}
	}
}

- (void)mergeSelectedItems
{
	Vector3D center = Vector3D();
	uint selectedCount = 0;
	
	for (uint i = 0; i < [items count]; i++)
	{
		if ([self isSelectedAtIndex:i])
		{
			selectedCount++;
			center += [[self itemAtIndex:i] position];
		}
	}
	
	if (selectedCount < 2)
		return;
	
	center /= selectedCount;
	
	Item *newItem = [[Item alloc] initWithPosition:center rotation:Quaternion() scale:Vector3D(1, 1, 1)];
	Mesh *mesh = [newItem mesh];
	
	Matrix4x4 firstMatrix, itemMatrix;
	
	firstMatrix.TranslateRotateScale([newItem position],
									 [newItem rotation],
									 [newItem scale]);
	
	firstMatrix = firstMatrix.Inverse();
	
	for (int i = 0; i < (int)[items count]; i++)
	{
		if ([self isSelectedAtIndex:i])
		{
			Item *item = [self itemAtIndex:i];
			Vector3D scale = [item scale];
			
			itemMatrix.TranslateRotateScale([item position],
											[item rotation],
											scale);
			
			Matrix4x4 finalMatrix = firstMatrix * itemMatrix;
			Mesh *itemMesh = [item mesh];
			
			[itemMesh transformWithMatrix:finalMatrix];
			
			// mirror detection, some component of scale is negative
			if (scale.x < 0.0f || scale.y < 0.0f || scale.z < 0.0f)
				[itemMesh flipAllTriangles];
				
			[mesh mergeWithMesh:itemMesh];
			[items removeObjectAtIndex:i];
			i--;
		}
	}
	
	[newItem setSelected:YES];
	[self addItem:newItem];
	[newItem release];
}

- (NSMutableArray *)currentManipulations
{
	NSMutableArray *manipulations = [[[NSMutableArray alloc] init] autorelease];
	
	for (uint i = 0; i < [self count]; i++)
	{
		Item *item = [self itemAtIndex:i];
		if ([item selected])
		{
			ItemManipulationState *itemState = [[ItemManipulationState alloc] initWithItem:item index:i];
			[manipulations addObject:itemState];
			[itemState release];
		}
	}
	
	return manipulations;
}

- (void)setCurrentManipulations:(NSMutableArray *)manipulations
{
	[self deselectAll];
	
	for (ItemManipulationState *manipulation in manipulations)
	{
		Item *item = [self itemAtIndex:[manipulation itemIndex]];
		[manipulation applyManipulationToItem:item];
	}
}

- (MeshManipulationState *)currentMeshManipulation
{
	for (uint i = 0; i < [self count]; i++)
	{
		Item *item = [self itemAtIndex:i];
		if ([item selected])
		{
			MeshManipulationState *meshState = [[MeshManipulationState alloc] initWithMesh:[item mesh]
																				 itemIndex:i];
			[meshState autorelease];
			return meshState;
		}
	}
	return nil;
}

- (void)setCurrentMeshManipulation:(MeshManipulationState *)manipulation
{
	[self deselectAll];
	
	Item *item = [self itemAtIndex:[manipulation itemIndex]];
	[item setSelected:YES];
	[manipulation applyManipulationToMesh:[item mesh]];
}

- (MeshFullState *)currentMeshFull
{
	for (uint i = 0; i < [self count]; i++)
	{
		Item *item = [self itemAtIndex:i];
		if ([item selected])
		{
			MeshFullState *meshState = [[MeshFullState alloc] initWithMesh:[item mesh]
																 itemIndex:i];
			[meshState autorelease];
			return meshState;
		}
	}
	return nil;
}

- (void)setCurrentMeshFull:(MeshFullState *)fullState
{
	[self deselectAll];
	
	Item *item = [self itemAtIndex:[fullState itemIndex]];
	[item setSelected:YES];
	[fullState applyFullToMesh:[item mesh]];
}

- (NSMutableArray *)currentSelection
{
	NSMutableArray *selection = [[[NSMutableArray alloc] init] autorelease];
	
	for (uint i = 0; i < [self count]; i++)
	{
		Item *item = [self itemAtIndex:i];
		if ([item selected])
		{
			NSNumber *number = [[NSNumber alloc] initWithUnsignedInt:i];
			[selection addObject:number];
			[number release];
		}
	}
	
	return selection;	
}

- (void)setCurrentSelection:(NSMutableArray *)selection
{
	[self deselectAll];
	
	for (NSNumber *number in selection)
	{
		[self setSelected:YES atIndex:[number unsignedIntValue]];
	}
}

- (NSMutableArray *)currentItems
{
	NSMutableArray *anItems = [[[NSMutableArray alloc] init] autorelease];
	
	for (uint i = 0; i < [self count]; i++)
	{
		Item *item = [self itemAtIndex:i];
		if ([item selected])
		{
			IndexedItem *indexedItem = [[IndexedItem alloc] initWithIndex:i item:item];
			[anItems addObject:indexedItem];
			[indexedItem release];
		}
	}
	
	return anItems;
}

- (void)setCurrentItems:(NSMutableArray *)anItems
{
	[self deselectAll];
	
	for (IndexedItem *indexedItem in anItems)
	{
		[self insertItem:[indexedItem item] atIndex:[indexedItem index]];
	}
}

- (NSMutableArray *)allItems
{
	NSMutableArray *anItems = [[[NSMutableArray alloc] init] autorelease];
	
	for (uint i = 0; i < [self count]; i++)
	{
		Item *clone = [[self itemAtIndex:i] clone];
		[anItems addObject:clone];
		[clone release];
	}
	
	return anItems;
}

- (void)setAllItems:(NSMutableArray *)anItems
{
	if (items == anItems)
		return;
	
	[items release];
	items = anItems;
	[items retain];
}

- (void)setSelectionFromIndexedItems:(NSMutableArray *)anItems
{
	[self deselectAll];
	
	for (IndexedItem *indexedItem in anItems)
	{
		[self setSelected:YES atIndex:[indexedItem index]];
	}
}

- (void)deselectAll
{
	for (uint i = 0; i < [self count]; i++)
		[self setSelected:NO atIndex:i];
}

- (void)getVertexCount:(uint *)vertexCount triangleCount:(uint *)triangleCount
{
	*vertexCount = 0;
	*triangleCount = 0;
	for (Item *item in items)
	{
		Mesh *mesh = [item mesh];
		*vertexCount += [mesh vertexCount];
		*triangleCount += [mesh triangleCount];
	}
}

@end