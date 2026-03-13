function results = eis_battery_workflow_complete_v2()
%{
EIS 电池体系自动分析工作流
===========================================================




【运行方式】
results = eis_battery_workflow_complete_v2();

【依赖】
- MATLAB 基础环境
- Optimization Toolbox（用于 lsqnonlin）
%}

clc;
fprintf('==============================================\n');
fprintf('EIS 自动分析工作流启动（升级版）\n');
fprintf('==============================================\n\n');

if exist('lsqnonlin','file') ~= 2
    error('未检测到 lsqnonlin。请确认已安装并启用 Optimization Toolbox。');
end

mode = menu('请选择分析模式', '单文件分析', '文件夹批量分析');
if mode == 0
    results = struct([]);
    disp('用户取消。');
    return;
end

if mode == 1
    [f, p] = uigetfile({'*.txt;*.csv','EIS files (*.txt, *.csv)'}, '选择 EIS 原始数据文件');
    if isequal(f,0)
        results = struct([]);
        disp('用户取消。');
        return;
    end
    fileList = {fullfile(p,f)};
    defaultOut = fullfile(p, 'result');
else
    p = uigetdir(pwd, '选择包含 EIS 原始数据的文件夹');
    if isequal(p,0)
        results = struct([]);
        disp('用户取消。');
        return;
    end
    files1 = dir(fullfile(p, '*.txt'));
    files2 = dir(fullfile(p, '*.csv'));
    files = [files1; files2];
    if isempty(files)
        error('所选文件夹中未找到 .txt 或 .csv 文件。');
    end
    fileList = cell(numel(files),1);
    for i = 1:numel(files)
        fileList{i} = fullfile(files(i).folder, files(i).name);
    end
    defaultOut = fullfile(p, 'result');
end

outRoot = uigetdir(fileparts(defaultOut), '选择输出文件夹（取消则默认使用 result 文件夹）');
if isequal(outRoot,0)
    outRoot = defaultOut;
end
if ~exist(outRoot,'dir')
    mkdir(outRoot);
end

allSummary = struct([]);
results = cell(numel(fileList),1);

for i = 1:numel(fileList)
    file = fileList{i};
    fprintf('----------------------------------------------\n');
    fprintf('正在处理 [%d/%d]: %s\n', i, numel(fileList), file);
    fprintf('----------------------------------------------\n');
    try
        one = processOneFile(file, outRoot);
        results{i} = one;
        allSummary = appendSummary(allSummary, makeSummaryStruct(one));
    catch ME
        warning('文件处理失败：%s\n错误信息：%s', file, ME.message);
        failResult = makeFailResult(file, ME.message);
        results{i} = failResult;
        allSummary = appendSummary(allSummary, makeSummaryStruct(failResult));
    end
end

summaryPath = fullfile(outRoot, 'summary_all_files.csv');
writeSummaryCSV(allSummary, summaryPath);
fprintf('\n已生成总汇总文件：%s\n', summaryPath);
fprintf('\n全部分析完成。\n');

if numel(results) == 1
    results = results{1};
end

end

%% ========================= 单文件处理 =========================
function result = processOneFile(file, outRoot)
[data, noteRead] = readEISFile(file);
N = numel(data.freq);
if N < 8
    error('有效数据点过少，无法进行可靠拟合。');
end

[~, baseName, ~] = fileparts(file);
sampleOut = fullfile(outRoot, safeName(baseName));
if ~exist(sampleOut,'dir')
    mkdir(sampleOut);
end

% 频率排序：高频 -> 低频
[~, idx] = sort(data.freq, 'descend');
data.freq = data.freq(idx);
data.Zre  = data.Zre(idx);
data.Zim  = data.Zim(idx);
data.Zexp = complex(data.Zre, data.Zim);

% 候选模型
models = getCandidateModels();

fitResults = struct([]);
for m = 1:numel(models)
    fr = fitOneModelMultiStart(models(m), data);
    if isempty(fitResults)
        fitResults = fr;
    else
        fitResults(end+1,1) = fr; %#ok<AGROW>
    end
end

% 去掉失败模型
keep = false(numel(fitResults),1);
for k = 1:numel(fitResults)
    keep(k) = isfield(fitResults(k),'status') && strcmp(fitResults(k).status,'ok');
end
fitResults = fitResults(keep);
if isempty(fitResults)
    error('所有候选模型拟合均失败。');
end

% 排序：先 BIC 后 AIC 再 RMSE
metricMat = [[fitResults.BIC].', [fitResults.AIC].', [fitResults.RMSE].'];
[~, ord] = sortrows(metricMat, [1 2 3]);
fitResults = fitResults(ord);

best = fitResults(1);

minAIC = min([fitResults.AIC]);
minBIC = min([fitResults.BIC]);
for k = 1:numel(fitResults)
    fitResults(k).deltaAIC = fitResults(k).AIC - minAIC;
    fitResults(k).deltaBIC = fitResults(k).BIC - minBIC;
end
best = fitResults(1);

% 拟合质量标签
fit_quality = assessFitQuality(best, data);

% 导出候选模型排名
rankingPath = fullfile(sampleOut, 'candidate_models_ranking.csv');
writeRankingCSV(fitResults, rankingPath);

% 导出最佳模型参数
paramPath = fullfile(sampleOut, 'best_model_parameters.csv');
writeBestParamsCSV(best, paramPath);

% 导出模型解释
explainPath = fullfile(sampleOut, 'model_selection_explanation.txt');
writeModelExplanation(explainPath, fitResults, best);

% 导出叠图数据
overlayDataPath = fullfile(sampleOut, 'nyquist_fit_overlay_data.csv');
writeOverlayData(data, best, overlayDataPath);

% 绘图
plotNyquistOverlay(data, best, fullfile(sampleOut, 'Nyquist_raw_vs_fit.png'));
plotBodeOverlay(data, best, fullfile(sampleOut, 'Bode_raw_vs_fit.png'));
plotResiduals(data, best, fullfile(sampleOut, 'Residuals.png'));

% 简要说明
note = strjoin({char(noteRead), char(fit_quality.note)}, ' | ');

result = struct();
result.file = file;
result.status = "ok";
result.nPoints = N;
result.best_model = string(best.model.name);
result.SSE = best.SSE;
result.variance = best.variance;
result.sigma2 = best.sigma2;
result.RMSE = best.RMSE;
result.AIC = best.AIC;
result.BIC = best.BIC;
result.deltaAIC = best.deltaAIC;
result.deltaBIC = best.deltaBIC;
result.n_param = best.nParam;
result.Rs = getNamedValue(best,'Rs');
result.Rsei_or_R1 = getNamedValue(best,'R1');
result.Rct_or_R2 = getNamedValue(best,'R2');
result.Rtotal_fit = sumPositiveR(best);
result.freq_max = max(data.freq);
result.freq_min = min(data.freq);
result.fit_quality = string(fit_quality.label);
result.manual_review_recommended = string(fit_quality.review);
result.note = string(note);
result.data = data;
result.best = best;
result.ranking = fitResults;
end

%% ========================= 文件读取 =========================
function [data, note] = readEISFile(file)
note = "读取成功";
ext = lower(filepartsExt(file));

raw = [];
if strcmp(ext,'.csv') || strcmp(ext,'.txt')
    raw = tryReadMatrix(file);
end

if isempty(raw) || size(raw,2) < 3 || sum(~isnan(raw(:,1))) < 5
    raw = parseTextNumeric(file);
end

if isempty(raw) || size(raw,2) < 3
    error('未能从文件中解析出至少三列数值数据（Freq, Zre, Zim）。');
end

freq = raw(:,1);
Zre  = raw(:,2);
Zim  = raw(:,3);

good = isfinite(freq) & isfinite(Zre) & isfinite(Zim) & (freq > 0);
freq = freq(good);
Zre = Zre(good);
Zim = Zim(good);

if isempty(freq)
    error('文件中没有有效的 EIS 数值数据。');
end

data = struct();
data.freq = freq(:);
data.Zre = Zre(:);
data.Zim = Zim(:);
end

function M = tryReadMatrix(file)
M = [];
try
    M = readmatrix(file);
catch
end
if isempty(M)
    try
        fid = fopen(file,'r');
        C = textscan(fid,'%f%f%f%*[^\n]','Delimiter',',','CollectOutput',1,'HeaderLines',0);
        fclose(fid);
        if ~isempty(C) && ~isempty(C{1})
            M = C{1};
        end
    catch
        if exist('fid','var') && fid>0
            fclose(fid);
        end
    end
end
end

function M = parseTextNumeric(file)
fid = fopen(file,'r');
if fid < 0
    error('无法打开文件：%s', file);
end
cleanup = onCleanup(@() fclose(fid));
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
lines = C{1};
rows = [];
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    line2 = strrep(line, ';', ',');
    nums = sscanf(line2, '%f,%f,%f,%f,%f');
    if numel(nums) >= 3
        rows(end+1,1:3) = nums(1:3).'; %#ok<AGROW>
    else
        nums2 = sscanf(line2, '%f %f %f %f %f');
        if numel(nums2) >= 3
            rows(end+1,1:3) = nums2(1:3).'; %#ok<AGROW>
        end
    end
end
M = rows;
end

%% ========================= 候选模型 =========================
function models = getCandidateModels()
models = struct([]);

models(1).name = 'Rs + (R1||Q1)';
models(1).paramNames = {'Rs','R1','Q1','a1'};
models(1).lb = [0,   0,   1e-12, 0.3];
models(1).ub = [1e6, 1e8, 1,     1.0];
models(1).fun = @model_1zarc;

models(2).name = 'Rs + (R1||Q1) + (R2||Q2)';
models(2).paramNames = {'Rs','R1','Q1','a1','R2','Q2','a2'};
models(2).lb = [0,   0,   1e-12, 0.3, 0,   1e-12, 0.3];
models(2).ub = [1e6, 1e8, 1,     1.0, 1e8, 1,     1.0];
models(2).fun = @model_2zarc;

models(3).name = 'Rs + (R1||Q1) + W';
models(3).paramNames = {'Rs','R1','Q1','a1','Aw'};
models(3).lb = [0,   0,   1e-12, 0.3, 0];
models(3).ub = [1e6, 1e8, 1,     1.0, 1e8];
models(3).fun = @model_1zarc_w;

models(4).name = 'Rs + (R1||Q1) + (R2||Q2) + W';
models(4).paramNames = {'Rs','R1','Q1','a1','R2','Q2','a2','Aw'};
models(4).lb = [0,   0,   1e-12, 0.3, 0,   1e-12, 0.3, 0];
models(4).ub = [1e6, 1e8, 1,     1.0, 1e8, 1,     1.0, 1e8];
models(4).fun = @model_2zarc_w;
end

%% ========================= 多起点拟合 =========================
function fr = fitOneModelMultiStart(model, data)
fr = makeEmptyFitResult(model);

w = 2*pi*data.freq(:);
Zexp = data.Zexp(:);
N = numel(Zexp);
k = numel(model.paramNames);

Rs0 = max(min(data.Zre), 0);
Rspan = max(data.Zre) - min(data.Zre);
if Rspan <= 0
    Rspan = max(abs(data.Zre));
end
if Rspan <= 0
    Rspan = 1;
end

switch model.name
    case 'Rs + (R1||Q1)'
        x0base = [max(Rs0,1e-6), max(Rspan,1), 1e-5, 0.8];
    case 'Rs + (R1||Q1) + (R2||Q2)'
        x0base = [max(Rs0,1e-6), max(0.4*Rspan,1), 1e-5, 0.85, max(0.6*Rspan,1), 1e-4, 0.7];
    case 'Rs + (R1||Q1) + W'
        x0base = [max(Rs0,1e-6), max(Rspan,1), 1e-5, 0.8, max(0.2*Rspan,1)];
    case 'Rs + (R1||Q1) + (R2||Q2) + W'
        x0base = [max(Rs0,1e-6), max(0.3*Rspan,1), 1e-5, 0.85, max(0.5*Rspan,1), 1e-4, 0.7, max(0.2*Rspan,1)];
    otherwise
        x0base = max(model.lb + 1e-9, 0.5*(model.lb + model.ub));
end

nStarts = 16;
X0 = generateStarts(x0base, model.lb, model.ub, nStarts);

bestCost = inf;
bestX = [];
bestZ = [];

opts = optimoptions('lsqnonlin', ...
    'Display','off', ...
    'MaxFunctionEvaluations',4000, ...
    'MaxIterations',800, ...
    'FunctionTolerance',1e-10, ...
    'StepTolerance',1e-10);

for s = 1:size(X0,1)
    x0 = X0(s,:);
    obj = @(x) residualVector(x, model, w, Zexp);
    try
        [x,resnorm,~,exitflag] = lsqnonlin(obj, x0, model.lb, model.ub, opts);
        if exitflag <= 0 || ~isfinite(resnorm)
            continue;
        end
        Zfit = model.fun(x, w);
        SSE = sum(abs(Zexp - Zfit).^2);
        if isfinite(SSE) && SSE < bestCost
            bestCost = SSE;
            bestX = x;
            bestZ = Zfit;
        end
    catch
    end
end

if isempty(bestX)
    fr.status = 'failed';
    fr.note = '拟合失败';
    return;
end

SSE = sum(abs(Zexp - bestZ).^2);
RMSE = sqrt(SSE / N);
dof = max(N - k, 1);
variance = SSE / dof;
sigma2 = variance;
AIC = N * log(max(SSE / N, realmin)) + 2*k;
BIC = N * log(max(SSE / N, realmin)) + k*log(max(N,2));

fr.status = 'ok';
fr.model = model;
fr.params = bestX(:).';
fr.paramTable = makeParamTable(model.paramNames, bestX);
fr.Zfit = bestZ;
fr.N = N;
fr.nParam = k;
fr.SSE = SSE;
fr.variance = variance;
fr.sigma2 = sigma2;
fr.RMSE = RMSE;
fr.AIC = AIC;
fr.BIC = BIC;
fr.deltaAIC = NaN;
fr.deltaBIC = NaN;
fr.note = '';
end

function X0 = generateStarts(x0base, lb, ub, nStarts)
d = numel(x0base);
X0 = zeros(nStarts, d);
X0(1,:) = clampVec(x0base, lb, ub);
for i = 2:nStarts
    scale = 10.^((rand(1,d)-0.5)*1.2);
    x = x0base .* scale;
    for j = 1:d
        if lb(j) >= 0.3 && ub(j) <= 1.0
            x(j) = min(max(x0base(j) + 0.15*randn, lb(j)), ub(j));
        end
    end
    X0(i,:) = clampVec(x, lb, ub);
end
end

function r = residualVector(x, model, w, Zexp)
Zfit = model.fun(x, w);
dz = Zexp - Zfit;
r = [real(dz); imag(dz)];
end

%% ========================= 电路模型 =========================
function Z = model_1zarc(x, w)
Rs = x(1); R1 = x(2); Q1 = x(3); a1 = x(4);
jw = 1i*w;
Z1 = 1 ./ (1./R1 + Q1 .* (jw).^a1);
Z = Rs + Z1;
end

function Z = model_2zarc(x, w)
Rs = x(1); R1 = x(2); Q1 = x(3); a1 = x(4); R2 = x(5); Q2 = x(6); a2 = x(7);
jw = 1i*w;
Z1 = 1 ./ (1./R1 + Q1 .* (jw).^a1);
Z2 = 1 ./ (1./R2 + Q2 .* (jw).^a2);
Z = Rs + Z1 + Z2;
end

function Z = model_1zarc_w(x, w)
Rs = x(1); R1 = x(2); Q1 = x(3); a1 = x(4); Aw = x(5);
jw = 1i*w;
Z1 = 1 ./ (1./R1 + Q1 .* (jw).^a1);
Zw = Aw ./ sqrt(jw + eps);
Z = Rs + Z1 + Zw;
end

function Z = model_2zarc_w(x, w)
Rs = x(1); R1 = x(2); Q1 = x(3); a1 = x(4); R2 = x(5); Q2 = x(6); a2 = x(7); Aw = x(8);
jw = 1i*w;
Z1 = 1 ./ (1./R1 + Q1 .* (jw).^a1);
Z2 = 1 ./ (1./R2 + Q2 .* (jw).^a2);
Zw = Aw ./ sqrt(jw + eps);
Z = Rs + Z1 + Z2 + Zw;
end

%% ========================= 结果评价 =========================
function fq = assessFitQuality(best, data)
fq = struct();
fq.label = "可信";
fq.review = "no";
msgs = {};

vals = best.params;
if any(~isfinite(vals))
    fq.label = "不可信";
    fq.review = "yes";
    msgs{end+1} = '存在非有限参数'; %#ok<AGROW>
end

for i = 1:numel(best.model.paramNames)
    pn = best.model.paramNames{i};
    if ~isempty(strfind(pn,'a'))
        a = vals(i);
        if a < 0.45 || a > 1.0
            fq.label = "可疑";
            fq.review = "yes";
            msgs{end+1} = ['CPE 指数异常: ', pn]; %#ok<AGROW>
        end
    end
end

Rs = getNamedValue(best, 'Rs');
hfErr = abs(data.Zre(1) - Rs);
if hfErr > max(0.1*max(abs(data.Zre(1)),1), 50)
    fq.label = "可疑";
    fq.review = "yes";
    msgs{end+1} = '高频截距偏差较大'; %#ok<AGROW>
end

span = max(data.Zre) - min(data.Zre);
if span <= 0, span = max(abs(data.Zre)); end
if span <= 0, span = 1; end
nrmse = best.RMSE / span;
if nrmse > 0.1
    fq.label = "可疑";
    fq.review = "yes";
    msgs{end+1} = 'RMSE 相对阻抗跨度偏大'; %#ok<AGROW>
end
if nrmse > 0.25
    fq.label = "不可信";
    fq.review = "yes";
    msgs{end+1} = 'RMSE 过大'; %#ok<AGROW>
end

if isempty(msgs)
    fq.note = "Fitting look reasonable";
else
    fq.note = string(strjoin(msgs, '; '));
end
end

%% ========================= 导出 =========================
function writeRankingCSV(fitResults, file)
rank = (1:numel(fitResults)).';
model = strings(numel(fitResults),1);
n_param = zeros(numel(fitResults),1);
SSE = zeros(numel(fitResults),1);
variance = zeros(numel(fitResults),1);
sigma2 = zeros(numel(fitResults),1);
RMSE = zeros(numel(fitResults),1);
AIC = zeros(numel(fitResults),1);
BIC = zeros(numel(fitResults),1);
deltaAIC = zeros(numel(fitResults),1);
deltaBIC = zeros(numel(fitResults),1);

for i = 1:numel(fitResults)
    model(i) = string(fitResults(i).model.name);
    n_param(i) = fitResults(i).nParam;
    SSE(i) = fitResults(i).SSE;
    variance(i) = fitResults(i).variance;
    sigma2(i) = fitResults(i).sigma2;
    RMSE(i) = fitResults(i).RMSE;
    AIC(i) = fitResults(i).AIC;
    BIC(i) = fitResults(i).BIC;
    deltaAIC(i) = fitResults(i).deltaAIC;
    deltaBIC(i) = fitResults(i).deltaBIC;
end

T = table(rank, model, n_param, SSE, variance, sigma2, RMSE, AIC, BIC, deltaAIC, deltaBIC);
writetable(T, file);
end

function writeBestParamsCSV(best, file)
names = string(best.model.paramNames(:));
values = best.params(:);
T = table(names, values, 'VariableNames', {'parameter','value'});
writetable(T, file);
end

function writeOverlayData(data, best, file)
freq = data.freq(:);
Zre_raw = real(data.Zexp(:));
Zim_raw = imag(data.Zexp(:));
Zre_fit = real(best.Zfit(:));
Zim_fit = imag(best.Zfit(:));
dZre = Zre_raw - Zre_fit;
dZim = Zim_raw - Zim_fit;
T = table(freq, Zre_raw, Zim_raw, Zre_fit, Zim_fit, dZre, dZim);
writetable(T, file);
end

function writeModelExplanation(file, fitResults, best)
fid = fopen(file, 'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'EIS 候选模型排序与统计指标说明\n');
fprintf(fid, '=====================================================\n\n');
fprintf(fid, '当前最佳模型：%s\n', best.model.name);
fprintf(fid, '最佳模型 BIC = %.6g, AIC = %.6g, RMSE = %.6g, variance = %.6g\n\n', ...
    best.BIC, best.AIC, best.RMSE, best.variance);

fprintf(fid, '一、各指标含义\n');
fprintf(fid, '1) SSE（残差平方和）\n');
fprintf(fid, '   SSE = sum(|Zexp - Zfit|^2)\n');
fprintf(fid, '   表示拟合曲线与原始数据之间的总偏差平方和，越小越好。\n\n');

fprintf(fid, '2) variance / sigma2（残差方差估计）\n');
fprintf(fid, '   variance = SSE / (N - k)\n');
fprintf(fid, '   其中 N 为数据点数，k 为模型参数数。\n');
fprintf(fid, '   表示在考虑自由度后，每个样本点平均误差强度的估计，越小越好。\n\n');

fprintf(fid, '3) RMSE（均方根误差）\n');
fprintf(fid, '   RMSE = sqrt(SSE / N)\n');
fprintf(fid, '   单位与阻抗相同（通常为欧姆），可直观表示平均误差量级，越小越好。\n\n');

fprintf(fid, '4) AIC（赤池信息准则）\n');
fprintf(fid, '   AIC = N*ln(SSE/N) + 2*k\n');
fprintf(fid, '   在误差之外对参数个数进行惩罚，避免过拟合，越小越好。\n\n');

fprintf(fid, '5) BIC（贝叶斯信息准则）\n');
fprintf(fid, '   BIC = N*ln(SSE/N) + k*ln(N)\n');
fprintf(fid, '   与 AIC 类似，但对复杂模型惩罚更强，通常比 AIC 更保守，越小越好。\n\n');

fprintf(fid, '二、推荐解读方式\n');
fprintf(fid, '1) 默认以 BIC 最小的模型作为首选模型。\n');
fprintf(fid, '2) 若多个模型的 deltaBIC 很接近（例如 < 2），说明模型优劣差别不大，\n');
fprintf(fid, '   需进一步结合 Nyquist 叠图、残差图和参数物理意义判断。\n');
fprintf(fid, '3) 不能只看 SSE / variance，因为参数更多的复杂模型通常更容易得到更小误差。\n');
fprintf(fid, '4) 对“没跑起来”“低频未闭合”“强非稳态”数据，应谨慎进行物理解释。\n\n');

fprintf(fid, '三、本样品候选模型排名（按 BIC 升序）\n');
fprintf(fid, 'rank\tmodel\tBIC\tAIC\tRMSE\tvariance\tdeltaBIC\n');
for i = 1:numel(fitResults)
    fprintf(fid, '%d\t%s\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\n', i, fitResults(i).model.name, ...
        fitResults(i).BIC, fitResults(i).AIC, fitResults(i).RMSE, fitResults(i).variance, fitResults(i).deltaBIC);
end
end

function writeSummaryCSV(allSummary, file)
if isempty(allSummary)
    T = table();
    writetable(T, file);
    return;
end
T = struct2table(allSummary);
writetable(T, file);
end

%% ========================= 绘图 =========================
function plotNyquistOverlay(data, best, outfile)
fig = figure('Visible','off','Color','w');
plot(real(data.Zexp), -imag(data.Zexp), 'o', 'MarkerSize', 5, 'DisplayName', '原始数据');
hold on;
plot(real(best.Zfit), -imag(best.Zfit), '-', 'LineWidth', 1.5, 'DisplayName', '拟合曲线');
xlabel('Real(Z) / Ohm');
ylabel('-Imag(Z) / Ohm');
title(sprintf('Nyquist Overlay | %s', best.model.name), 'Interpreter', 'none');
legend('Location','best');
grid on;
axis tight;
try
    axis equal;
catch
end
text(real(data.Zexp(1)), -imag(data.Zexp(1)), sprintf('  HF %.3g Hz', data.freq(1)), 'FontSize', 8);
text(real(data.Zexp(end)), -imag(data.Zexp(end)), sprintf('  LF %.3g Hz', data.freq(end)), 'FontSize', 8);
saveFigureCompat(fig, outfile);
close(fig);
end

function plotBodeOverlay(data, best, outfile)
fig = figure('Visible','off','Color','w');
subplot(2,1,1);
semilogx(data.freq, abs(data.Zexp), 'o', 'MarkerSize', 4, 'DisplayName', '原始数据');
hold on;
semilogx(data.freq, abs(best.Zfit), '-', 'LineWidth', 1.2, 'DisplayName', '拟合曲线');
ylabel('|Z| / Ohm');
title(sprintf('Bode Overlay | %s', best.model.name), 'Interpreter', 'none');
legend('Location','best');
grid on;

subplot(2,1,2);
semilogx(data.freq, angle(data.Zexp)*180/pi, 'o', 'MarkerSize', 4, 'DisplayName', '原始数据');
hold on;
semilogx(data.freq, angle(best.Zfit)*180/pi, '-', 'LineWidth', 1.2, 'DisplayName', '拟合曲线');
xlabel('Frequency / Hz');
ylabel('Phase / deg');
grid on;
saveFigureCompat(fig, outfile);
close(fig);
end

function plotResiduals(data, best, outfile)
fig = figure('Visible','off','Color','w');
dZ = data.Zexp - best.Zfit;
subplot(2,1,1);
semilogx(data.freq, real(dZ), '-o', 'MarkerSize', 4);
ylabel('Delta Real(Z) / Ohm');
title('Residuals');
grid on;

subplot(2,1,2);
semilogx(data.freq, imag(dZ), '-o', 'MarkerSize', 4);
xlabel('Frequency / Hz');
ylabel('Delta Imag(Z) / Ohm');
grid on;
saveFigureCompat(fig, outfile);
close(fig);
end

function saveFigureCompat(fig, outfile)
try
    exportgraphics(fig, outfile, 'Resolution', 200);
catch
    saveas(fig, outfile);
end
end

%% ========================= 汇总结构体 =========================
function s = appendSummary(allSummary, one)
fields = getSummaryFieldOrder();
one = alignSummaryStruct(one, fields);
if isempty(allSummary)
    s = one;
    return;
end
tmp = repmat(alignSummaryStruct(struct(), fields), numel(allSummary), 1);
for k = 1:numel(allSummary)
    tmp(k,1) = alignSummaryStruct(allSummary(k), fields);
end
s = [tmp; one];
end

function fields = getSummaryFieldOrder()
fields = { ...
    'file', ...
    'status', ...
    'nPoints', ...
    'best_model', ...
    'SSE', ...
    'variance', ...
    'sigma2', ...
    'RMSE', ...
    'AIC', ...
    'BIC', ...
    'deltaAIC', ...
    'deltaBIC', ...
    'n_param', ...
    'Rs', ...
    'Rsei_or_R1', ...
    'Rct_or_R2', ...
    'Rtotal_fit', ...
    'freq_max', ...
    'freq_min', ...
    'fit_quality', ...
    'manual_review_recommended', ...
    'note'};
end

function out = alignSummaryStruct(in, fields)
out = struct();
for i = 1:numel(fields)
    f = fields{i};
    if isfield(in, f)
        out.(f) = in.(f);
    else
        switch f
            case {'file','status','best_model','fit_quality','manual_review_recommended','note'}
                out.(f) = "";
            otherwise
                out.(f) = NaN;
            end
        end
    end
end

function s = makeSummaryStruct(result)
s = struct();
s.file = string(result.file);
s.status = string(result.status);
s.nPoints = result.nPoints;
s.best_model = string(result.best_model);
s.SSE = result.SSE;
s.variance = result.variance;
s.sigma2 = result.sigma2;
s.RMSE = result.RMSE;
s.AIC = result.AIC;
s.BIC = result.BIC;
s.deltaAIC = result.deltaAIC;
s.deltaBIC = result.deltaBIC;
s.n_param = result.n_param;
s.Rs = result.Rs;
s.Rsei_or_R1 = result.Rsei_or_R1;
s.Rct_or_R2 = result.Rct_or_R2;
s.Rtotal_fit = result.Rtotal_fit;
s.freq_max = result.freq_max;
s.freq_min = result.freq_min;
s.fit_quality = result.fit_quality;
s.manual_review_recommended = result.manual_review_recommended;
s.note = string(result.note);
end

function fr = makeFailResult(file, msg)
fr = struct();
fr.file = string(file);
fr.status = "failed";
fr.nPoints = NaN;
fr.best_model = "";
fr.SSE = NaN;
fr.variance = NaN;
fr.sigma2 = NaN;
fr.RMSE = NaN;
fr.AIC = NaN;
fr.BIC = NaN;
fr.deltaAIC = NaN;
fr.deltaBIC = NaN;
fr.n_param = NaN;
fr.Rs = NaN;
fr.Rsei_or_R1 = NaN;
fr.Rct_or_R2 = NaN;
fr.Rtotal_fit = NaN;
fr.freq_max = NaN;
fr.freq_min = NaN;
fr.fit_quality = "failed";
fr.manual_review_recommended = "yes";
fr.note = string(msg);
end

function fr = makeEmptyFitResult(model)
fr = struct();
fr.status = 'failed';
fr.model = model;
fr.params = [];
fr.paramTable = table();
fr.Zfit = [];
fr.N = NaN;
fr.nParam = numel(model.paramNames);
fr.SSE = inf;
fr.variance = inf;
fr.sigma2 = inf;
fr.RMSE = inf;
fr.AIC = inf;
fr.BIC = inf;
fr.deltaAIC = inf;
fr.deltaBIC = inf;
fr.note = '';
end

%% ========================= 小工具 =========================
function T = makeParamTable(names, vals)
T = table(string(names(:)), vals(:), 'VariableNames', {'parameter','value'});
end

function v = getNamedValue(best, name)
v = NaN;
for i = 1:numel(best.model.paramNames)
    if strcmp(best.model.paramNames{i}, name)
        v = best.params(i);
        return;
    end
end
end

function R = sumPositiveR(best)
R = 0;
for i = 1:numel(best.model.paramNames)
    n = best.model.paramNames{i};
    if ~isempty(strfind(n,'R'))
        val = best.params(i);
        if isfinite(val) && val > 0
            R = R + val;
        end
    end
end
end

function x = clampVec(x, lb, ub)
x = min(max(x, lb), ub);
end

function e = filepartsExt(file)
[~,~,e] = fileparts(file);
end

function s = safeName(s)
if isstring(s), s = char(s); end
bad = '<>:"/\|?*';
for i = 1:numel(bad)
    s(s==bad(i)) = '_';
end
if isempty(s)
    s = 'sample';
end
end
