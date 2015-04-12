import random
import mondrianBlock, pdb
import numpy as np

class MondrianTree(object):
    '''
    the class used to represent a Mondrian tree
    '''

    budget = None
    rowLB = None
    rowUB = None
    columnLB = None
    columnUB = None
    root = None
    leafBlockDic = None
    leafCutDic = None
    rowCutDic = None
    columnCutDic = None
    inCutDic = None
    
    def __init__(self, budget, rowLB, rowUB, columnLB, columnUB, inLB, inUB):
        self.root = mondrianBlock.MondrianBlock(budget, rowLB, rowUB, columnLB, columnUB, inLB, inUB,
                             None, None, None, None, None)
        self.leafBlockDic = {self.root:True}
        self.leafCutDic = {}
        self.rowCutDic = {}
        self.columnCutDic = {}
        self.inCutDic = {}

        leafBlockLst = self.leafBlockDic.keys()
        
        cutNum = 0
        level = 0
        while len(leafBlockLst) > 0:
            level += 1
            newLeafBlockLst = []
            for leafBlock in leafBlockLst:
                
                length = leafBlock.rowUB - leafBlock.rowLB
                width = leafBlock.columnUB - leafBlock.columnLB
                height = leafBlock.inUB - leafBlock.inLB

                cost = random.expovariate(length + width + height)
                if not cost > leafBlock.budget:
                    leftChild = None
                    rightChild = None
                    cutPos = None
                    cutDir = None
                    #make a cut along axis proportional to its respective length
                    tmp = np.random.multinomial(1,np.array([length, width, height])/(1.0*(length+width+height)))
                    cutDir = np.where(tmp==1)[0][0]
                    if cutDir == 0:
                        cutPos = leafBlock.rowLB + random.random() * length
                        leftChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, leafBlock.rowLB, cutPos,
                                         leafBlock.columnLB, leafBlock.columnUB, leafBlock.inLB, leafBlock.inUB , None, None,
                                         None, None, leafBlock)
                        rightChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, cutPos, leafBlock.rowUB,
                                         leafBlock.columnLB, leafBlock.columnUB, leafBlock.inLB, leafBlock.inUB , None, None,
                                         None, None, leafBlock)
                    elif cutDir == 1:
                        cutPos = leafBlock.columnLB + random.random() * width
                        leftChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, leafBlock.rowLB, leafBlock.rowUB,
                                             leafBlock.columnLB, cutPos, leafBlock.inLB, leafBlock.inUB , None, None,
                                             None, None, leafBlock)
                        rightChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, leafBlock.rowLB, leafBlock.rowUB,
                                             cutPos, leafBlock.columnUB, leafBlock.inLB, leafBlock.inUB , None, None,
                                             None, None, leafBlock)
                    else:
                        cutPos = leafBlock.inLB + random.random() * height
                        leftChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, leafBlock.rowLB, leafBlock.rowUB,
                                            leafBlock.columnLB, leafBlock.columnUB, leafBlock.inLB, cutPos , None, None,
                                             None, None, leafBlock)
                        rightChild = mondrianBlock.MondrianBlock(leafBlock.budget-cost, leafBlock.rowLB, leafBlock.rowUB,
                                             leafBlock.columnLB, leafBlock.columnUB, cutPos, leafBlock.inUB , None, None,
                                             None, None, leafBlock)
                    cutNum += 1
                    
                    self.addCut(leafBlock, cutDir, cutPos, leftChild, rightChild)
                    newLeafBlockLst.append(leftChild)
                    newLeafBlockLst.append(rightChild)
                else:
                    self.leafBlockDic[leafBlock] = True
                
            leafBlockLst = newLeafBlockLst


    def getRandomLeafBlock(self):
        leafBlock = self.leafBlockDic.keys()[random.randint(0, len(self.leafBlockDic)-1)]
        return leafBlock
    
    def getRandomLeafCut(self):
        leafCut = None
        if len(self.leafCutDic) > 0:
            leafCut = self.leafCutDic.keys()[random.randint(0, len(self.leafCutDic)-1)]
        return leafCut
    
    def addCut(self, leafBlock, cutDir, cutPos, leftChild, rightChild):
        self.leafBlockDic.pop(leafBlock)
        
        if not leftChild.isLeaf() or not rightChild.isLeaf():
            exit('this block should have two leaves as children!')
        leafBlock.setCut(cutDir, cutPos, leftChild, rightChild)
            
        self.leafBlockDic[leafBlock.leftChild] = True
        self.leafBlockDic[leafBlock.rightChild] = True
        
        if self.leafCutDic.has_key(leafBlock.getParent()):
            self.leafCutDic.pop(leafBlock.getParent())
        self.leafCutDic[leafBlock] = True
        
        if leafBlock.cutDir == 0:
            self.rowCutDic[leafBlock.cutPos] = leafBlock
        elif leafBlock.cutDir == 1:
            self.columnCutDic[leafBlock.cutPos] = leafBlock
        else:
            self.inCutDic[leafBlock.cutPos] = leafBlock

    def removeLeafCut(self, leafCut):
        self.leafBlockDic.pop(leafCut.leftChild)
        self.leafBlockDic.pop(leafCut.rightChild)
        self.leafBlockDic[leafCut] = True
        
        if leafCut.getParent() is not None:
            if ((leafCut.getParent().leftChild is not None) 
                and (leafCut.getParent().rightChild is not None) 
                and leafCut.getParent().leftChild.isLeaf() 
                and leafCut.getParent().rightChild.isLeaf()):
                self.leafCutDic[leafCut.getParent()] = True
        
        if leafCut.cutDir == 0:
            self.rowCutDic.pop(leafCut.cutPos)
        elif leafCut.cutDir == 1:
            self.columnCutDic.pop(leafCut.cutPos)
        else:
            self.inCutDic.pop(leafCut.cutPos)
        
        self.leafCutDic.pop(leafCut)
        
        leafCut.removeCut()

    # def getRowCutDic(self):
    #     return self.rowCutDic
    
    # def getColumnCutDic(self):
    #     return self.columnCutDic
        
    def getLeafBlockDic(self):
        return self.leafBlockDic
    
    def getLeafCutDic(self):
        return self.leafCutDic
        
    def representation(self, fOutput=None):
        blockLst = [self.root]
        level = 0
        while len(blockLst) > 0:
            level += 1
            outputLine = 'Level %s:\t' % level
            newBlockLst = []
            for block in blockLst:
                if not (block.leftChild is None):
                    newBlockLst.append(block.leftChild)
                if not (block.rightChild is None):
                    newBlockLst.append(block.rightChild)
                if not (block.cutPos is None):
                    if block.cutDir == 0:
                        outputLine += ('row cut at %s in [%s X %s,%s X %s,%s X %s]\t' % (block.cutPos, 
                                                                      block.rowLB,block.rowUB,block.columnLB,block.columnUB,block.inLB, block.inUB))
                    elif block.cutDir == 1:
                        outputLine += ('column cut at %s in [%s X %s,%s X %s,%s X %s]\t' % (block.cutPos, 
                                                                      block.rowLB,block.rowUB,block.columnLB,block.columnUB,block.inLB, block.inUB))
                    else:
                        outputLine += ('in cut at %s in [%s X %s,%s X %s,%s X %s]\t' % (block.cutPos, 
                                                                      block.rowLB,block.rowUB,block.columnLB,block.columnUB,block.inLB, block.inUB))
            if fOutput is None:
                print outputLine
            else:
                fOutput.write(outputLine + '\n')
            blockLst = newBlockLst




if __name__ == '__main__':
    tree = MondrianTree(1, 0, 1, 0, 1, 0, 1)
    tree.representation()
    # leafCut = tree.getRandomLeafCut()
    # if leafCut is not None:
    #     print leafCut
    #     print leafCut.leftChild.isLeaf()
    #     print leafCut.rightChild.isLeaf()
    #     print leafCut.leftChild
    #     print leafCut.rightChild
    #     tree.removeLeafCut(leafCut)
    #     tree.representation()