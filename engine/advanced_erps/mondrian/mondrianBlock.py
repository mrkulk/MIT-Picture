
#import math
import utils

class MondrianBlock(object):
    '''
    the class used to represent a Mondrian block or node
    '''

    budget = None
    rowLB = None
    rowUB = None
    columnLB = None
    columnUB = None
    inLB = None
    inUB = None
    cutPos = None
    cutDir = None
    leftChild = None
    rightChild = None
    parent = None
    
    def __init__(self, budget, rowLB, rowUB, columnLB, columnUB, inLB, inUB,
                 cutPos, cutDir, leftChild, rightChild, parent):
        '''
        Constructor
        '''
        if (leftChild is not None 
            and rightChild is None) or (leftChild is None 
                                        and rightChild is not None):
            exit('One child node is None and the other is not None!')
        if (cutPos is not None 
            and cutDir is None) or (cutPos is None
                                    and cutDir is not None):
            exit('Cutting position and direction are not consistent!')
        if (cutPos is not None):
            if leftChild is None or rightChild is None:
                exit('Non-leaf node must have two child nodes!')
        if cutDir is not None and (cutPos > 1 or cutPos < 0):
            exit('Illegal cutting position!')
        if rowLB >= rowUB or columnLB >= columnUB or inLB >= inUB:
            exit('Illegal block size!')
        self.budget = budget * 1.0
        self.rowLB = rowLB * 1.0
        self.rowUB = rowUB * 1.0
        self.columnLB = columnLB * 1.0
        self.columnUB = columnUB * 1.0
        self.inLB = inLB * 1.0
        self.inUB = inUB * 1.0
        self.cutPos = cutPos
        self.cutDir = cutDir
        self.leftChild = leftChild
        self.rightChild = rightChild
        self.parent = parent
        
    def getParent(self):
        return self.parent
    
    def getLeftChild(self):
        return self.leftChild
    
    def getRightChild(self):
        return self.rightChild
    
    def setCut(self, cutDir, cutPos, leftChild, rightChild):
        if cutDir is None or cutPos is None or leftChild is None or rightChild is None:
            exit('Error cut info!')
        else:
            self.cutPos = cutPos
            self.cutDir = cutDir
            self.leftChild = leftChild
            self.rightChild = rightChild
            
    def removeCut(self):
            self.cutPos = None
            self.cutDir = None
            self.leftChild = None
            self.rightChild = None
    
    def isLeaf(self):
        return self.cutPos is None
    
    def __eq__(self, another):
        if isinstance(another, MondrianBlock):
            if (self.budget == another.budget 
                and self.rowLB == another.rowLB
                and self.rowUB == another.rowUB
                and self.columnLB == another.columnLB
                and self.columnUB == another.columnUB
                and self.inLB == another.inLB
                and self.inUB == another.inUB):
                return True
        return False
    
    def __str__(self):
        return 'block with budget %s at (%s, %s) x (%s, %s) x (%s, %s)' % (self.budget, self.rowLB, self.rowUB, self.columnLB, self.columnUB, self.inLB, self.inUB)
    
    def computeLogLikelihood(self, data, xi, eta, beta, dimension):
        likelihood = util.Lgamma(dimension * beta) - dimension * util.Lgamma(beta)
        countDic = {}
        columnIdxLst = []
        sum = 0
        for columnIdx in range(0, len(eta)-1):
            columnPos = eta[columnIdx]
            if columnPos > self.columnLB and columnPos < self.columnUB:
                columnIdxLst.append(columnIdx)
        
        for rowIdx in range(0, len(xi)-1):
            rowPos = xi[rowIdx]
            if rowPos > self.rowLB and rowPos < self.rowUB:
                for columnIdx in columnIdxLst:
                    datum = data[rowIdx][columnIdx]
                    if datum is not None:
                        if not countDic.has_key(datum):
                            countDic[datum] = 1
                        else:
                            countDic[datum] += 1
                        sum += 1
        
        for datum, count in countDic.iteritems():
            likelihood += util.Lgamma(beta + count)
        likelihood += (dimension - len(countDic)) * util.Lgamma(beta)
        likelihood -= util.Lgamma(dimension * beta + sum)
        return likelihood
        
        