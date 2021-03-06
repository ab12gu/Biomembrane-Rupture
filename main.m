% -------------------------------------------------------------------------
% Simulation of Cell Fracture
% By: Abhay Gupta
% 08/06/2017
% Rules:
% 1. Begin with an initial MLV size
% 2. Slowly spread the lipid-bilayer radially
% 3. Strategically/Probabilistically assign pins across expansion
% 4. Strategically/Probabilistically assign cluster of pins across
% expansion
% 5. Define a bond strength to each pin
% 6. Break bonds if the tension in pin exceeds bond strength of pin
% 7. End expansion once the diamater of expansion is half the frame size
% -------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Clear System
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create a Video file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


videoSave = 0;

if videoSave == 1
    v = VideoWriter([...
       'G:\Team Drives\AG-MT Research\Videos\Production\' ...
       'CircularGrowth4.avi']);
    v.FrameRate = 10; %FrameRate = Frames/Second
    open(v);
else
    v = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Color Settings 
%%% Range from 0 -> 1
%%% [Red Green Blue] Variable        Range          Color
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cmap = [...
    0.00 0.00 0.00;  %Background   || -inf <x=< 2   (Black)
    1.00 0.10 0.10;  %MLV          || 2    <x=< 3   (Light Red)
    0.85 0.00 0.00;  %Bilayer      || 3    <x=< 4   (Brush Red)
    1 1 1;
    %0.90 0.00 0.00;  %Pinned BL    || 4    <x=< 5   (Red)
    0.50 0.00 0.00]; %Fractured BL || 5    <x=< inf (Dark Red)
colormap(cmap)  


%NOTE: The plotted value is Array Value + 1

%More Colors:
    %0.95 0.00 0.34;     (Hot Pink)
    %0.30 0.50 0.77;     (Turquoise)
    %0.20 0.30 0.40;     (Blue)
    
%Legend for code:
    %Background = 0 (or 1)
    %MLV        = 1
    %Bilayer    = 2
    %Pinned BL  = 3
    %Fracture   = 4

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Paramaterized Variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
maxRadius = 200; %Maximum radius for bilayer growth
set_probability = 0; %IF zero, the pin probability function is constant
constant_pin_probability = 0.001; %Probability of expanded bilayer nodes turning into pins
min_pin = 0; %Set the minimum expansion radius for pinning to begin

%IF set_probability ~= 0, the pin probability is a function
%%Nonlinear probability across BL (increase pins probability further
    %%away from center
    maxProb = 0.001;
    factor = 1;
    minProb = maxProb*factor;
    factor2 = 1/9;
    %min_pin = maxRadius*factor2;

clusProb = 1;         %Probability of new pin sites turning into cluster of pins
percReleased = 8;       %Percent Tension Released after node breaks
initialBondStr = 0.6;       %Pin Bond Strength
stretch = 25/32;        %The amount of stretch each new cluster bond has || Lower bond strength
MLVradius  = 6;         %MLV Radius
minOutputRadius = 100;  %The minimum radius required for image to be graphed
k = 0;                  %Percentage of how much other closer pins affect further pins

%Cluster Tension Parameters:
kc = 1; %Constant
pc = 1; %Exponential

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initial Calculated Paramters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

maxAreaBL = pi*maxRadius^2; %Maximum Area of the Bilayer 

%Frame/Array size
frameSize = maxRadius*4;
center = frameSize/2;
max_rows = frameSize;
max_col = frameSize;

%Center of MLV 
xcen = (max_col+1)/2;
ycen = (max_rows+1)/2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Pre-allocating Memory
new_circle = zeros(frameSize);
previous_circle = zeros(frameSize);
nodes_at_circumference   = zeros(frameSize);

% Amount of pins & invaders
amount_of_pins = 0;
pins = [];

%Expanded unpinned BL nodes for the last 3 expansions
unpinned3    = [];
unpinned2    = [];
unpinned1    = [];
unpinned0    = [];

%Expanded pinned BL nodes for the last 3 expansions
cluster_pins3      = [];
cluster_pins2      = [];
cluster_pins1      = [];
cluster_pins0      = [];

%Set the initial MLV paramters
%NOTE: 'm' is a 4 times the current radius of the bilayer
start = (MLVradius)*4+1;
minIteration = start+4;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Begin lipid bi-layer spread across Si02 surface
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for iteration = start:2:frameSize    
    
    %Recomputes array for the expansion of the bilayer
    [expRadius, new_circle] = Bilayer_Expansion(iteration, center, new_circle); 
    %NOTE:all the MLV & EXP terms == 1 (no pins yet)
     
    %Creates the initial MLV array
    if iteration == start
        [MLVnodes] = MLV(new_circle, max_rows);
        MLVandBL = new_circle; %Store current expansion as the total output
        continue;
    end
    
    %Stores the new circumference of nodes into expansion
    nodes_at_circumference = new_circle - previous_circle; %
    previous_circle = new_circle; %Reset Previous Circle to Current Circle
    
    %Find the the new indexes for each node
    [i, j] = find(nodes_at_circumference);
    amount_of_new_nodes = length(i);
    
    nodes_at_circumference = zeros(frameSize); %reset variable
        
    %Store the last four expansion's unpinned elements   
    unpinned3 = unpinned2;
    unpinned2 = unpinned1;
    unpinned1 = unpinned0;
    unpinned0 = [];
    
    %Store the last four expansion's pinned elements
    cluster_pins3 = cluster_pins2;
    cluster_pins2 = cluster_pins1;
    cluster_pins1 = cluster_pins0;
    cluster_pins0 = [];
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Find all pinning sites
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    for h = 1:amount_of_new_nodes
        
        index = indxx(i(h), j(h), max_col); 
        
        %Set the probabilty of pinning
        if set_probability == 0
            pinDensityValue = constant_pin_probability;
        else
            %A Non-linear probability of pinning occuring radially
                %expRadius is the changing input variable
            pinDensityValue = (maxProb-minProb)/(maxRadius-min_pin)...
                *(expRadius-min_pin)+minProb; %expRadius: current radius of the BL
        end
                        
        if amount_of_new_nodes == 10 %What da fuck?
            pinDensityValue = 0.1;
        end
        
        %Save each new pin site into the pin array (pins)
            %radMin is the minimum radius needed for pin sites to form
        if rand(1) < pinDensityValue && expRadius > min_pin 

            %Store pin into output array
            nodes_at_circumference(i(h),j(h)) = 3; %+2 for output value
          
            amount_of_pins = size(pins,2)+1;
            
            [pins] = createPin(xcen, ycen, i(h),... 
                j(h), pins, maxRadius, expRadius, index, amount_of_pins);
             
            %Check if site becomes a cluster type pin
            if rand(1) < clusProb
                cluster_pins0 = [cluster_pins0;index]; %Cluster
                pins(10,amount_of_pins) = 1;
                clusterLength = pins(10,amount_of_pins);
                %Bond Strength:
                pins(11,amount_of_pins) = BondStrength(clusterLength,stretch,initialBondStr);
            else
                pins(10,amount_of_pins) = 0; %Not cluster
                %Bond Strength:(set cluster length to 1... should change later...)
                pins(11,amount_of_pins) = BondStrength(1,stretch,initialBondStr);
            end

        %Else, store as regular expanded BL node
        else
            %if not a pin, change name to not pin and add rand number
            nodes_at_circumference(i(h),j(h)) = rand+1;
            unpinned0 = [unpinned0; index]; %Store as new BL 
        end
    end   
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Spread pinning chains (clusters of pins)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Total invader nodes from 4 iterations
    unpinned0123 = [unpinned3; unpinned2; unpinned1; unpinned0];
    cluster_pins0123 = [cluster_pins3; cluster_pins2; cluster_pins1; cluster_pins0];    
    clear i j;
                          
    [pins, nodes_at_circumference, MLVandBL, threshold, ...
        cluster_pins0, cluster_pins1, cluster_pins2, cluster_pins3, cluster_pins0123, ...
        unpinned0, unpinned1, unpinned2, unpinned3, unpinned0123] = ...
        clusterSpread(iteration, minIteration, xcen, ycen, cluster_pins0123, unpinned0123, ...
        maxRadius, MLVandBL, nodes_at_circumference, unpinned0, unpinned1, ...
        unpinned2, unpinned3, cluster_pins0, cluster_pins1, cluster_pins2, cluster_pins3, stretch, ...
        pins, max_rows, max_col, initialBondStr);
        
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Add new nodes to output (MLVandBL)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    MLVandBL = MLVandBL + nodes_at_circumference; 
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Recalculate Tension (after each iteration)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    invadedPins = [];
    
    for P = 1:amount_of_pins
        pinRad = pins(2,P);
        [pins, tension] = tensionCalc(pins, expRadius, k, pinRad, ...
            maxRadius, P);
                            
        bondStrength = pins(11,P);
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Fractal Fracture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %If the tension exceeds bond strength 
         %And is a chained pin (cluster)(10)
          %And is not previously broken: (8)
            %Do Fractal Fracture       
        if tension > bondStrength && pins(10,P) > 0 && ~(pins(8,P))
                
            [pins, LNBindex, MLVandBL] = ...
            cluster(pins, P, max_rows, max_col, MLVandBL, ...
                threshold, ycen, xcen, maxRadius, ...
                unpinned0, unpinned1, unpinned2, unpinned3, ...
                cluster_pins0, cluster_pins1, cluster_pins2, cluster_pins3);
        
            if isempty(LNBindex)
                continue;
            end
        end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CircularGrowth
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Check Tension & if not cluster
        if tension > bondStrength && pins(10,P) == 0
            
            [pins, invadedPins, MLVandBL, n] = ... 
                circularGrowth(invadedPins, frameSize, tension, ...
                percReleased, pins, P, xcen, ycen,  MLVandBL, ...
                max_rows, max_col); 
        end
                
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Expand the invaded pins
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Check if any pins circular fractured into previously pinned
        %locations
        if ~isempty(invadedPins)
            [pins, invadedPins, MLVandBL, v] = growthChain(pins, ...
                invadedPins, frameSize, ...
                max_rows, max_col, n, xcen, ycen, MLVandBL, constant_pin_probability, ...
                clusProb, maxRadius, expRadius, videoSave, MLVnodes, P, v);
        end
    end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Visual Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if expRadius > minOutputRadius
        v = output(MLVandBL, constant_pin_probability, clusProb, maxRadius, frameSize, ...
            expRadius, videoSave, pins, MLVnodes, v);
    end
    
    clear f
end

if videoSave == 1
    close(v);
end

%%END of File
