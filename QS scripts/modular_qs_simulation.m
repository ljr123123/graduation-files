function modular_qs_simulation()
    %% 参数设置
    params.NI0 = 0.1;      % LuxI菌初始密度
    params.NR0 = 0.1;      % LuxR菌初始密度
    params.A0 = 0;         % 初始AHL浓度
    params.rI = 0.7;       % LuxI生长速率
    params.rR = 0.6;       % LuxR生长速率
    params.K = 1.0;        % 环境承载力
    params.kA = 0.1;       % AHL产生速率
    params.dA = 0.05;      % AHL降解速率
    params.delta = 0.01;   % 群体消耗系数
    params.KA = 5;         % Hill阈值(nM)
    params.n = 2;          % Hill系数
    params.tspan = 0:0.1:24;

    %% 微分方程定义
    dydt = @(t,y) [
        % LuxI菌生长
        params.rI * y(1) * (1 - (y(1)+y(2))/params.K);  
        
        % LuxR菌生长
        params.rR * y(2) * (1 - (y(1)+y(2))/params.K);  
        
        % AHL浓度变化
        params.kA * y(1) - params.dA * y(3) - params.delta * (y(1)+y(2)) * y(3); 
    ];

    %% 数值求解
    [t,Y] = ode45(dydt, params.tspan, [params.NI0; params.NR0; params.A0]);
    NI = Y(:,1);    % LuxI密度
    NR = Y(:,2);    % LuxR密度
    A = Y(:,3);     % AHL浓度
    
    %% 协同响应计算
    Output = (A.^params.n) ./ (params.KA^params.n + A.^params.n);
    Activation = A > params.KA;

    %% 可视化
    figure;
    
    % 菌群密度
    subplot(3,1,1);
    plot(t, NI, 'b', t, NR, 'r', 'LineWidth', 2);
    legend('LuxI Strain', 'LuxR Strain');
    ylabel('Population Density');
    title('Bacterial Growth Dynamics');
    
    % AHL浓度
    subplot(3,1,2);
    plot(t, A, 'm', 'LineWidth', 2);
    hold on;
    plot([0 t(end)], [params.KA params.KA], '--k');
    ylabel('AHL (nM)');
    legend('AHL Concentration', 'Threshold');
    
    % 协同响应
    subplot(3,1,3);
    plot(t, Output, 'g', 'LineWidth', 2);
    ylabel('QS Output');
    xlabel('Time (hours)');
    title('Cooperative Response');
end