function [pins, nodes_at_circumference, MLVandBL, threshold, ...
    pinned0, pinned1, pinned2, pinned3, cluster_pins0123, ...
    unpinned0, unpinned1, unpinned2, unpinned3, unpinned0123] = ...
    clusterSpread(iteration, ...
        minM, xcen, ycen, cluster_pins0123, unpinned0123, ...
        maxRadius, MLVandBL, nodes_at_circumference, unpinned0, unpinned1, ...
        unpinned2, unpinned3, pinned0, pinned1, pinned2, pinned3, ...
        stretch, pins, max_rows, max_col, initialBondStr)
    
%CLUSTERSPREAD Checks each NB of cluster pin and spreads the pinning across BL
 
    threshold = [];
    checkedPins = 0;
    
    while(checkedPins ~= length(cluster_pins0123)) 
                
        %Skip the first 3 expansions of pinning
        if iteration <= minM
            break;
        end
        
        checkedPins = checkedPins + 1; %Increment

        %index of cluster
        index = cluster_pins0123(checkedPins);        

        i = ceil(index/max_rows);
        j = mod(index-1,max_col)+1;
        
        %Check if neighbors are lower than threshold
            %if so, check if node is unpinned
                %if so, expand and store as new pin*
        %increment an overall cluster addition
        x = i-xcen;
        y = j-ycen;
        pin_distance_to_center = sqrt(x^2+y^2);
        
        %1.4
        %Longer chains at larger radiuses
        threshold = thresholdEQN(pin_distance_to_center, maxRadius);
        
        for m = 1:3
            for n = 1:3
                
                %find the neighbor's value (NB)
                iNB = i+(m-2);
                jNB = j+(n-2);
                indexNB = (iNB-1)*max_rows+jNB;
                
                %Check if neighbor is a BL node within expansion
                circumIndex = find(unpinned0 == indexNB);
                
                if  isempty(circumIndex) %Maybe unnecesssary???
                    T = MLVandBL(iNB, jNB);
                else
                    T = nodes_at_circumference(iNB ,jNB);
                end

                %if neighbor value is not a BL, skip neighbor
                if T <= 1 || T >= 2
                    continue;
                end
                                
                %Check if neighbor is below threshold,
                    %Change neighbor BL node to pinned node
                if T < threshold
                    
                    %Find Location of neighbor
                    unpinnedIndex = find(unpinned0123 == indexNB);
                    unpinnedIndex1  = find(unpinned1 == indexNB);
                    unpinnedIndex2  = find(unpinned2 == indexNB);
                    unpinnedIndex3  = find(unpinned3 == indexNB);
                                        
                    %Count the additional pins
                    pinLength = size(pins,2)+1;
            
                    %Store pin into output
                    %Change node from unpinned to pinned
                    if ~isempty(circumIndex) 
                        nodes_at_circumference(iNB,jNB) = 3;
                        unpinned0(circumIndex) = [];
                        pinned0 = [pinned0; indexNB];
                    else
                        MLVandBL(iNB, jNB) = 3;
                        if ~isempty(unpinnedIndex1)
                            unpinned1(unpinnedIndex1) = [];
                            pinned1 = [pinned1; indexNB];
                        elseif ~isempty(unpinnedIndex2)
                            unpinned2(unpinnedIndex2) = [];
                            pinned2 = [pinned2; indexNB];
                        elseif ~isempty(unpinnedIndex3)
                            unpinned3(unpinnedIndex3) = [];
                            pinned3 = [pinned3; indexNB];
                        end
                    end
                    
                    %add new cluster to cluster list
                    cluster_pins0123 = [cluster_pins0123; indexNB];
                    
                    %remove node from both curr & pc elem
                    unpinned0123(unpinnedIndex) = [];
                    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Pin Storage & Tension Calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    x = iNB - xcen;
                    y = jNB - ycen;
                    currRad = sqrt(x^2+y^2);
                    
                    [pins] =createPin(xcen, ycen,iNB, jNB,... 
                        pins, maxRadius, currRad, indexNB, pinLength);

                    %Amount of times pin exceeds tension limit
                    Loc = find(index == pins(1,:));
                    pins(8, pinLength) = pins(8,Loc);
                    
                    %Amount of tension
                    pins(9, pinLength) = 0;
                    
                    %Store as a cluster
                    pins(10,pinLength) = 1+pins(10,Loc);
                    clusterLength = pins(10,pinLength);
                    
                    %Store the new bond strength
                    pins(11,pinLength) = BondStrength(clusterLength,stretch,initialBondStr);;

                end
            end
        end
    end

end

