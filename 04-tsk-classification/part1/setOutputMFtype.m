function fis = setOutputMFtype(fis, mfType)
%SETOUTPUTMFTYPE  Αλλάζει τον τύπο των output MFs σε 'constant' (singleton)
%
%  fis = setOutputMFtype(fis, 'constant')
%
%  Για TSK μοντέλα σε προβλήματα ταξινόμησης, η εκφώνηση
%  προτείνει χειροκίνητη αλλαγή από 'linear' σε 'constant'.

for outIdx = 1:numel(fis.Outputs)
    for mfIdx = 1:numel(fis.Outputs(outIdx).MembershipFunctions)
        oldParams = fis.Outputs(outIdx).MembershipFunctions(mfIdx).Parameters;

        fis.Outputs(outIdx).MembershipFunctions(mfIdx).Type = mfType;

        if strcmp(mfType, 'constant')
            % Κρατάμε μόνο την πρώτη παράμετρο (bias term)
            fis.Outputs(outIdx).MembershipFunctions(mfIdx).Parameters = ...
                oldParams(end);
        end
    end
end

end