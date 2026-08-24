%% Regenerate every figure in ../figures from the CSVs in ../data
%
% Run from this folder. No toolboxes required.
%
% Speed-up is referenced to the slowest measured point in each series, and
% efficiency is speed-up divided by the core-count ratio over the same
% reference, so a perfectly scaling series sits on 1.0.

clear; clc

here    = fileparts(mfilename('fullpath'));
if isempty(here); here = pwd; end
datadir = fullfile(here, '..', 'data');
figdir  = fullfile(here, '..', 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end

S = readtable(fullfile(datadir, 'single_node.csv'), 'TextType', 'string');
M = readtable(fullfile(datadir, 'multi_node.csv'),  'TextType', 'string');

%% ---------------------------------------------------------------- fig 1
% Wall clock against core count, one line per machine/case, single node.
f1 = figure('Visible','off','Position',[100 100 760 520]);
series = unique(S(:, {'machine','workload'}), 'rows', 'stable');
hold on
for k = 1:height(series)
    m = S.machine == series.machine(k) & S.workload == series.workload(k);
    [c, idx] = sort(S.cores(m));
    w = S.wall_s(m); w = w(idx);
    plot(c, w, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
         'DisplayName', sprintf('%s, %s', series.machine(k), series.workload(k)));
end
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on; xlabel('cores'); ylabel('wall clock per run (s)');
title('Single node: wall clock vs cores');
legend('Location','southwest'); legend boxoff
exportgraphics(f1, fullfile(figdir, 'single_node_wallclock.png'), 'Resolution', 150);

%% ---------------------------------------------------------------- fig 2
% Speed-up against cores, with the ideal line. The workstation is the point:
% it flattens and then turns back up.
f2 = figure('Visible','off','Position',[100 100 760 520]);
hold on
for k = 1:height(series)
    m = S.machine == series.machine(k) & S.workload == series.workload(k);
    [c, idx] = sort(S.cores(m));
    w = S.wall_s(m); w = w(idx);
    plot(c, w(1)./w, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
         'DisplayName', sprintf('%s, %s', series.machine(k), series.workload(k)));
end
cr = [min(S.cores) max(S.cores)];
plot(cr, cr/cr(1), 'k:', 'LineWidth', 1.2, 'DisplayName', 'ideal');
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on; xlabel('cores'); ylabel('speed-up vs slowest point in series');
title('Single node: speed-up vs cores');
legend('Location','northwest'); legend boxoff
exportgraphics(f2, fullfile(figdir, 'single_node_speedup.png'), 'Resolution', 150);

%% ---------------------------------------------------------------- fig 3
% Parallel efficiency. Falling below 1 is normal; the question is how fast.
f3 = figure('Visible','off','Position',[100 100 760 520]);
hold on
for k = 1:height(series)
    m = S.machine == series.machine(k) & S.workload == series.workload(k);
    [c, idx] = sort(S.cores(m));
    w = S.wall_s(m); w = w(idx);
    plot(c, (w(1)./w) ./ (c/c(1)), '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
         'DisplayName', sprintf('%s, %s', series.machine(k), series.workload(k)));
end
yline(1, 'k:', 'LineWidth', 1.2, 'HandleVisibility','off');
hold off
set(gca, 'XScale', 'log');
grid on; ylim([0 1.15]);
xlabel('cores'); ylabel('parallel efficiency');
title('Single node: parallel efficiency');
legend('Location','southwest'); legend boxoff
exportgraphics(f3, fullfile(figdir, 'single_node_efficiency.png'), 'Resolution', 150);

%% ---------------------------------------------------------------- fig 4
% Multi node. This is the result that contradicts the usual advice.
f4 = figure('Visible','off','Position',[100 100 760 520]);
cpn = unique(M.cores_per_node, 'stable');
hold on
for k = 1:numel(cpn)
    m = M.cores_per_node == cpn(k);
    [n, idx] = sort(M.nodes(m));
    w = M.wall_s(m); w = w(idx);
    plot(n, w, '-o', 'LineWidth', 1.6, 'MarkerSize', 7, ...
         'DisplayName', sprintf('%d cores/node', cpn(k)));
end
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
xticks([1 2 3 4 8 16]); xticklabels({'1','2','3','4','8','16'});
grid on; xlabel('nodes'); ylabel('wall clock per run (s)');
title('Multi node: adding nodes makes it faster');
legend('Location','southwest'); legend boxoff
exportgraphics(f4, fullfile(figdir, 'multi_node_wallclock.png'), 'Resolution', 150);

fprintf('wrote 4 figures to %s\n', figdir);

%% ------------------------------------------------------------- summary
fprintf('\nOwl vs Tinkercliffs, fluid+particles, matched cores:\n');
for c = [32 64]
    o = S.wall_s(S.machine=="owl"          & S.workload=="fluid+particles" & S.cores==c);
    t = S.wall_s(S.machine=="tinkercliffs" & S.workload=="fluid+particles" & S.cores==c);
    if ~isempty(o) && ~isempty(t)
        fprintf('  %3d cores: owl %4d s, tinkercliffs %4d s -> %.2fx\n', c, o, t, t/o);
    end
end
fprintf('\nMulti-node speed-up (14 cores/node): %.2fx from 1 to 16 nodes\n', ...
    M.wall_s(M.cores_per_node==14 & M.nodes==1) / M.wall_s(M.cores_per_node==14 & M.nodes==16));
