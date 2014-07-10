/*
 * The MIT License (MIT)
 
 * Created by Tarun Tyagi on 06/07/14.
 * Copyright (c) 2014 Tarun Tyagi. All rights reserved.
 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "ClearTextLabel.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreText.h>

#define to_CFAttrString (__bridge CFAttributedStringRef)

#define Width(r)  r.size.width
#define Height(r) r.size.height

#define DefaultBGColor [UIColor colorWithRed:78/255.0 green:78/255.0 blue:78/255.0 alpha:0.5]

#if DEBUG
#define CTLog(format, ...) NSLog(format, ##__VA_ARGS__)
#else
#define CTLog(format, ...)
#endif

@implementation ClearTextLabel

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        bgFillColor = DefaultBGColor;
        
        // Keep the backgroundColor's copy for later use while drawing
        if(self.backgroundColor != nil)
            bgFillColor = [self.backgroundColor copy];
        
        /*
         * opaque, default is YES. opaque views must fill their entire bounds or
         * the results are undefined. The active CGContext in drawRect: will not 
         * have been cleared and may have non-zeroed pixels
         */
        self.opaque = NO;
    }
    return self;
}

-(id)initWithCoder:(NSCoder*)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        bgFillColor = DefaultBGColor;
        
        // Keep the backgroundColor's copy for later use while drawing
        if(self.backgroundColor != nil)
            bgFillColor = [self.backgroundColor copy];
        
        /*
         * opaque, default is YES. opaque views must fill their entire bounds or
         * the results are undefined. The active CGContext in drawRect: will not
         * have been cleared and may have non-zeroed pixels
         */
        self.opaque = NO;
    }
    
    return self;
}

/*
 * Only override drawRect: if you perform custom drawing.
 * An empty implementation adversely affects performance during animation.
 */
-(void)drawRect:(CGRect)rect
{
    // Get the context, make it transparent
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    
    // Prepare NSMutableString from the text / attributedText available
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = self.textAlignment;
    NSDictionary *attributes = @{NSFontAttributeName:self.font,
                                 NSParagraphStyleAttributeName:paragraphStyle};
    
    NSAttributedString* text = nil;
    if([self.attributedText length] > 0)
    {
        text = [[NSAttributedString alloc] initWithString:self.attributedText.string
                                               attributes:attributes];
    }
    else
    {
        text = [[NSAttributedString alloc] initWithString:self.text
                                               attributes:attributes];
    }
    
    // Use AttributedString to create a Core Text FrameSetter
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString(to_CFAttrString text);
    
    /*
     * Get a frame from the FrameSetter using infinite String Range
     * (see 'CTFramesetterCreateFrame' definition) & Our label's bounds
     */
    CGPathRef boundsPath = CGPathCreateWithRect(self.bounds, NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0),
                                                boundsPath, NULL);
    
    // Create lines array from the frame
    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger linesCount = CFArrayGetCount(lines);
    
    // Decide how many lines the label does need to draw actually
    NSInteger numLines = ((self.numberOfLines > 0 && self.numberOfLines < linesCount) ?
                          self.numberOfLines : linesCount);
    
    // Find out maximum height that a line can take
    CGFloat maxLineHeight = 0.0f;
    for(CFIndex lineIndex=0; lineIndex<numLines; lineIndex++)
    {
        CTLineRef lineRef = CFArrayGetValueAtIndex(lines, lineIndex);
        CGRect lineRect = CTLineGetBoundsWithOptions(lineRef, kCTLineBoundsUseOpticalBounds);
        
        if(maxLineHeight < lineRect.size.height)
            maxLineHeight = lineRect.size.height;
    }
    
    // Calculate the vertical padding offset to be used at top & bottom
    CGFloat yPaddingOffset = (Height(rect) - (maxLineHeight*numLines)) / 2;
    
    // Start a path that will include all the letters' CGPath to be drawn
    CGMutablePathRef lettersPath = CGPathCreateMutable();
    
    // Start iterating linewise
    for(CFIndex lineIndex=0; lineIndex<numLines; lineIndex++)
    {
        CTLineRef lineRef = CFArrayGetValueAtIndex(lines, lineIndex);
        
        CFRange strRange = CTLineGetStringRange(lineRef);
        NSParagraphStyle* paragraphStyle = [text attribute:NSParagraphStyleAttributeName
                                                   atIndex:strRange.location
                                            effectiveRange:NULL];
        NSTextAlignment alignment = paragraphStyle.alignment;
        
        /*
         * What's flush Factor ?
         * (see CTLineGetPenOffsetForFlush definition)
         */
        CGFloat flushFactor = 0.0f;
        if(alignment == NSTextAlignmentLeft)
            flushFactor = 0.0f;
        else if(alignment == NSTextAlignmentCenter)
            flushFactor = 0.5f;
        else if(alignment == NSTextAlignmentRight)
            flushFactor = 1.0f;
        
        // Get all the glyphRuns for a lineRef, get penOffset using flushFactor
        CFArrayRef glyphRuns = CTLineGetGlyphRuns(lineRef);
        CGFloat penOffset = CTLineGetPenOffsetForFlush(lineRef, flushFactor, Width(rect));
        
        // Get to the baseline of current line
        yPaddingOffset += maxLineHeight;
        
        // Iterate each glyphRun present in the line
        for(CFIndex glyphRunIndex=0; glyphRunIndex<CFArrayGetCount(glyphRuns); glyphRunIndex++)
        {
            // Get FONT for this glyphRun using 'kCTFontAttributeName' from attributes
            CTRunRef glyphRun = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, glyphRunIndex);
            CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(glyphRun), kCTFontAttributeName);
            
            // Iterate each GLYPH in a glyphRun
            for(CFIndex glyphIndex=0; glyphIndex<CTRunGetGlyphCount(glyphRun); glyphIndex++)
            {
                // Get Glyph one by one & Glyph-Position
                CFRange glyphRange = CFRangeMake(glyphIndex, 1);
                CGGlyph glyph;
                CGPoint position;
                CTRunGetGlyphs(glyphRun, glyphRange, &glyph);
                CTRunGetPositions(glyphRun, glyphRange, &position);
                
                // Adjust position.x to include penOffset for lineRef
                position.x += penOffset;
                
                /*
                 * Get the CGPath for glyph, transform this path to adjust 
                 * horizontal & vertical paddings, initially it's flipped
                 * vertically, so we need to flip vertically (inverse) 
                 * to make it in right orientation.
                 */
                CGPathRef letterPath = CTFontCreatePathForGlyph(runFont, glyph, NULL);
                CGAffineTransform t =  CGAffineTransformMakeTranslation(position.x, yPaddingOffset);
                t = CGAffineTransformScale(t, 1, -1);
                CGPathRef transformedLetterPath = CGPathCreateMutableCopyByTransformingPath(letterPath, &t);
                
                /*
                 * Add this processed letterPath to lettersPath that will have
                 * all the letters' CGPath for later filling use
                 */
                CGPathAddPath(lettersPath, NULL, transformedLetterPath);
            }
        }
    }
    
    /*
     * Prepare UIBezierPath using our rect and needed cornerRadius
     * Add lettersPath as a subpath to this parentPath
     * Use 'evenOddFillRule' to skip drawing on lettersPath
     * fill the parentPath using requiredFillColor
     * all the path except letter bounds is filled &
     * letters remain transparent
     */
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                                    cornerRadius:self.layer.cornerRadius];
    [path appendPath:[UIBezierPath bezierPathWithCGPath:lettersPath]];
    path.usesEvenOddFillRule = YES;
    
    [bgFillColor set];
    [path fill];
}

#pragma mark
#pragma mark<Property Setters>
#pragma mark

/*
 * Property Setters update the corresponding property of
 * their super (UILabel) and indicate 'self' that
 * it needs to redraw.
 */
-(void)setBackgroundColor:(UIColor*)backgroundColor
{
    if(![backgroundColor isEqual:[UIColor clearColor]])
    {
        bgFillColor = [backgroundColor copy];
        [self setNeedsDisplay];
    }
}

-(void)setText:(NSString*)text
{
    [super setText:text];
    [self setNeedsDisplay];
}

-(void)setAttributedText:(NSAttributedString*)attributedText
{
    [super setAttributedText:attributedText];
    [self setNeedsDisplay];
}

-(void)setTextAlignment:(NSTextAlignment)textAlignment
{
    [super setTextAlignment:textAlignment];
    [self setNeedsDisplay];
}

-(void)setTextColor:(UIColor*)textColor
{
    // An empty implementation prevents UILabel from setting textColor
}

-(void)setFont:(UIFont*)font
{
    [super setFont:font];
    [self setNeedsDisplay];
}

-(void)setNumberOfLines:(NSInteger)numberOfLines
{
    [super setNumberOfLines:numberOfLines];
    [self setNeedsDisplay];
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay];
}

@end
